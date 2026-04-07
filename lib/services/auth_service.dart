import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService() {
    // S'assurer que la persistance est activée (elle l'est par défaut, mais on explicite)
    _auth.setPersistence(Persistence.LOCAL);
  }

  /// Stream de l'utilisateur actuel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

  /// Connexion avec email et mot de passe
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        return await getUserData(result.user!.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Inscription avec email et mot de passe
  Future<UserModel?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String telephone,
    required String adresse,
    String? ibanMasked,
  }) async {
    try {
      print('=== AuthService.createUserWithEmailAndPassword ===');
      print('Email: $email');
      print('Nom: $nom');

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('Firebase Auth créé avec succès: ${result.user?.uid}');

      if (result.user != null) {
        final user = UserModel(
          id: result.user!.uid,
          nom: nom,
          prenom: prenom,
          email: email.trim(),
          telephone: telephone,
          adresse: adresse,
          ibanMasked: ibanMasked,
          role: UserRole.borrower,
          createdAt: DateTime.now(),
        );

        print('Création du document Firestore...');
        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(user.toJson());

        print('Document Firestore créé avec succès');
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('Exception générale: $e');
      print('Type: ${e.runtimeType}');
      throw 'Erreur lors de la création du compte: $e';
    }
  }

  /// Récupération des données utilisateur
  Future<UserModel?> getUserData(String uid) async {
    try {
      print(
        '📊 AuthService.getUserData() - Récupération données pour UID: $uid',
      );

      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('📄 Données brutes Firestore: $data');

        final user = UserModel.fromJson(data);
        print(
          '👤 UserModel créé - Nom: ${user.nom}, Rôle: ${user.role}, IsAdmin: ${user.isAdmin}',
        );

        return user;
      }

      print('❌ Document utilisateur n\'existe pas pour UID: $uid');
      return null;
    } catch (e) {
      print('❌ Erreur getUserData: $e');
      throw Exception(
        'Erreur lors de la récupération des données utilisateur: $e',
      );
    }
  }

  /// Mise à jour des données utilisateur
  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .update(user.copyWith(updatedAt: DateTime.now()).toJson());
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  /// Réinitialisation du mot de passe
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  /// Gestion des exceptions Firebase Auth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email.';
      case 'weak-password':
        return 'Le mot de passe est trop faible.';
      case 'invalid-email':
        return 'L\'adresse email n\'est pas valide.';
      case 'user-disabled':
        return 'Ce compte utilisateur a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Veuillez réessayer plus tard.';
      default:
        return 'Une erreur est survenue: ${e.message}';
    }
  }
}
