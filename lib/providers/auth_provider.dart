import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true; // Nouveau : état d'initialisation
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing; // Nouveau getter
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;

  /// Initialiser le provider avec l'état actuel et persistance de session
  Future<void> init() async {
    print('🔐 AuthProvider.init() - Démarrage...');

    // Vérifier d'abord s'il y a un utilisateur déjà connecté (persistance)
    final User? currentFirebaseUser = _authService.currentUser;
    if (currentFirebaseUser != null) {
      print('🔐 Utilisateur persistant trouvé: ${currentFirebaseUser.uid}');
      try {
        _currentUser = await _authService.getUserData(currentFirebaseUser.uid);
        print('🔐 Données utilisateur récupérées: ${_currentUser?.nom}');
      } catch (e) {
        print('❌ Erreur récupération données utilisateur persistant: $e');
        _errorMessage = 'Erreur lors du chargement des données utilisateur';
      }
    }

    // Marquer l'initialisation comme terminée
    _isInitializing = false;
    notifyListeners();

    // Écouter les changements d'état d'authentification
    _authService.authStateChanges.listen((User? user) async {
      print('🔐 Changement état auth: ${user?.uid ?? "null"}');
      if (user != null) {
        try {
          _currentUser = await _authService.getUserData(user.uid);
          print('🔐 Utilisateur connecté: ${_currentUser?.nom}');
        } catch (e) {
          print('❌ Erreur chargement données: $e');
          _errorMessage = 'Erreur lors du chargement des données utilisateur';
        }
      } else {
        _currentUser = null;
        print('🔐 Utilisateur déconnecté');
      }
      _isInitializing = false; // S'assurer que c'est marqué comme terminé
      notifyListeners();
    });
  }

  /// Connexion
  Future<bool> signIn(String email, String password) async {
    print('🔐 AuthProvider.signIn() - Début connexion pour: $email');
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('👤 Utilisateur connecté: ${_currentUser?.nom}');
      print('🔑 Rôle utilisateur: ${_currentUser?.role}');
      print('👑 Est admin: ${_currentUser?.isAdmin}');
      print('🎯 IsLoggedIn: $isLoggedIn');
      print('🎯 IsAdmin: $isAdmin');

      return _currentUser != null;
    } catch (e) {
      print('❌ Erreur connexion: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Inscription
  Future<bool> signUp({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String telephone,
    required String adresse,
    String? ibanMasked,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        nom: nom,
        prenom: prenom,
        telephone: telephone,
        adresse: adresse,
        ibanMasked: ibanMasked,
      );
      return _currentUser != null;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Réinitialisation du mot de passe
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Déconnexion complète avec nettoyage des données de prêts
  Future<void> signOutAndClearData(dynamic loanProvider) async {
    _setLoading(true);
    try {
      // Timeout pour éviter les blocages
      await _authService.signOut().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // En cas de timeout, forcer la déconnexion locale
        },
      );

      _currentUser = null;
      notifyListeners(); // Notifier immédiatement le changement d'état

      // Nettoyer les données de prêts
      if (loanProvider != null) {
        try {
          loanProvider.clearAllData();
        } catch (e) {
          // Ignorer les erreurs de nettoyage, ce n'est pas critique
        }
      }
    } catch (e) {
      // En cas d'erreur, forcer quand même la déconnexion locale
      _currentUser = null;
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<bool> updateProfile(UserModel updatedUser) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.updateUserData(updatedUser);
      _currentUser = updatedUser;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}
