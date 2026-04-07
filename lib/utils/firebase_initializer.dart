import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirebaseInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialiser les données de test pour le développement
  static Future<void> initializeTestData() async {
    try {
      // Créer un utilisateur admin de test
      await _createTestAdmin();

      // Créer un utilisateur emprunteur de test
      await _createTestBorrower();

      print('✅ Données de test initialisées avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des données de test: $e');
    }
  }

  /// Créer un administrateur de test
  static Future<void> _createTestAdmin() async {
    const adminEmail = 'admin@chafin.com';
    const adminPassword = 'admin123';

    try {
      // Vérifier si l'admin existe déjà
      final existingAdmin = await _firestore
          .collection('users')
          .where('email', isEqualTo: adminEmail)
          .get();

      if (existingAdmin.docs.isNotEmpty) {
        print('ℹ️  Utilisateur admin déjà existant');
        return;
      }

      // Créer le compte Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      if (result.user != null) {
        // Créer le profil admin dans Firestore
        final admin = UserModel(
          id: result.user!.uid,
          nom: 'Test',
          prenom: 'Administrateur',
          email: adminEmail,
          telephone: '+33123456789',
          adresse: '123 Rue de l\'Admin, 75001 Paris',
          role: UserRole.admin,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(admin.toJson());

        print('✅ Utilisateur admin créé: $adminEmail / $adminPassword');
      }
    } catch (e) {
      print('⚠️  Erreur lors de la création de l\'admin: $e');
    }
  }

  /// Créer un emprunteur de test
  static Future<void> _createTestBorrower() async {
    const borrowerEmail = 'emprunteur@test.com';
    const borrowerPassword = 'test123';

    try {
      // Vérifier si l'emprunteur existe déjà
      final existingBorrower = await _firestore
          .collection('users')
          .where('email', isEqualTo: borrowerEmail)
          .get();

      if (existingBorrower.docs.isNotEmpty) {
        print('ℹ️  Utilisateur emprunteur déjà existant');
        return;
      }

      // Créer le compte Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: borrowerEmail,
        password: borrowerPassword,
      );

      if (result.user != null) {
        // Créer le profil emprunteur dans Firestore
        final borrower = UserModel(
          id: result.user!.uid,
          nom: 'Dupont',
          prenom: 'Jean',
          email: borrowerEmail,
          telephone: '+33987654321',
          adresse: '456 Avenue de l\'Emprunteur, 69001 Lyon',
          ibanMasked: 'FR76****0001',
          role: UserRole.borrower,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(borrower.toJson());

        print(
          '✅ Utilisateur emprunteur créé: $borrowerEmail / $borrowerPassword',
        );
      }
    } catch (e) {
      print('⚠️  Erreur lors de la création de l\'emprunteur: $e');
    }
  }

  /// Supprimer toutes les données de test
  static Future<void> clearTestData() async {
    try {
      // Supprimer tous les utilisateurs de test
      final usersSnapshot = await _firestore.collection('users').get();

      for (final doc in usersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Supprimer tous les prêts
      final loansSnapshot = await _firestore.collection('loans').get();

      for (final doc in loansSnapshot.docs) {
        await doc.reference.delete();
      }

      // Supprimer tous les échéanciers
      final schedulesSnapshot = await _firestore.collection('schedules').get();

      for (final doc in schedulesSnapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ Données de test supprimées avec succès');
    } catch (e) {
      print('❌ Erreur lors de la suppression des données de test: $e');
    }
  }
}
