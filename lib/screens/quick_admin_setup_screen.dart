import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuickAdminSetupScreen extends StatefulWidget {
  const QuickAdminSetupScreen({super.key});

  @override
  State<QuickAdminSetupScreen> createState() => _QuickAdminSetupScreenState();
}

class _QuickAdminSetupScreenState extends State<QuickAdminSetupScreen> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _cleanupExistingAccount() async {
    setState(() {
      _isLoading = true;
      _status = 'Nettoyage des anciens comptes...';
    });

    try {
      const email = 'admin@chafin.com';
      const password = 'Admin123456';

      setState(() {
        _status = 'Suppression du compte Firebase Auth...';
      });

      // Étape 1: Se connecter avec le compte admin existant pour le supprimer
      try {
        print('🔐 Tentative de connexion pour suppression...');
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final userId = credential.user!.uid;
        print('✅ Connecté pour suppression - UID: $userId');

        // Supprimer le compte Firebase Auth
        await credential.user!.delete();
        print('🗑️ Compte Firebase Auth supprimé');

        setState(() {
          _status = 'Suppression du document Firestore...';
        });

        // Supprimer le document Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        print('🗑️ Document Firestore supprimé');
      } catch (authError) {
        print(
          '⚠️ Erreur connexion (normal si compte n\'existe pas): $authError',
        );

        // Si la connexion échoue, essayer de supprimer les documents Firestore directement
        setState(() {
          _status = 'Suppression des documents orphelins...';
        });

        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        for (var doc in querySnapshot.docs) {
          print('🗑️ Suppression document orphelin: ${doc.id}');
          await doc.reference.delete();
        }
      }

      // S'assurer d'être déconnecté
      await FirebaseAuth.instance.signOut();
      print('🚪 Déconnexion après nettoyage');

      setState(() {
        _status = '✅ Nettoyage complet terminé !';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nettoyage complet ! Vous pouvez maintenant créer un compte propre.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur nettoyage: $e');
      setState(() {
        _status = '❌ Erreur nettoyage: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createCleanAdminAccount() async {
    setState(() {
      _isLoading = true;
      _status = 'Création du compte admin...';
    });

    try {
      // Email et mot de passe fixes pour simplifier
      const email = 'admin@chafin.com';
      const password = 'Admin123456';

      setState(() {
        _status = 'Création dans Firebase Auth...';
      });

      // Créer le compte Firebase Auth
      print('🚀 QuickAdmin: Création du compte Firebase Auth...');
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final userId = credential.user!.uid;
      print('✅ QuickAdmin: Compte Firebase Auth créé - UID: $userId');

      setState(() {
        _status = 'Création du document utilisateur...';
      });

      // Créer le document utilisateur avec des données propres (pas de timestamps)
      final userData = {
        'id': userId,
        'nom': 'Administrateur Chafin',
        'email': email,
        'telephone': '+33123456789',
        'adresse': '123 Rue Admin, Paris',
        'role': 'admin', // Enum sera géré par fromJson
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': null,
        'ibanMasked': null,
      };

      print('📄 QuickAdmin: Données à écrire dans Firestore: $userData');
      print('🔥 QuickAdmin: Écriture dans /users/$userId');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData);

      print('✅ QuickAdmin: Document Firestore créé avec succès!');

      // Déconnecter l'utilisateur fraîchement créé pour éviter la confusion
      await FirebaseAuth.instance.signOut();
      print('🚪 QuickAdmin: Déconnexion automatique effectuée');

      // Vérification que le document existe bien
      setState(() {
        _status = 'Vérification du document créé...';
      });

      final docCheck = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (docCheck.exists) {
        print('✅ QuickAdmin: Vérification OK - Document existe dans Firestore');
        print('📊 QuickAdmin: Contenu du document: ${docCheck.data()}');
      } else {
        print(
          '❌ QuickAdmin: PROBLÈME - Document n\'existe pas dans Firestore!',
        );
      }

      setState(() {
        _status = '✅ Compte admin créé avec succès !';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compte admin créé ! Utilisez admin@chafin.com / Admin123456',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erreur Firebase Auth';

      if (e.code == 'email-already-in-use') {
        message =
            'Le compte admin existe déjà ! Utilisez admin@chafin.com / Admin123456';

        setState(() {
          _status = '✅ Compte admin existe déjà !';
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Compte admin existe ! Utilisez admin@chafin.com / Admin123456',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      } else if (e.code == 'weak-password') {
        message = 'Mot de passe trop faible';
      } else if (e.code == 'invalid-email') {
        message = 'Email invalide';
      }

      setState(() {
        _status = '❌ $message';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _status = '❌ Erreur: $e';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Admin Simple'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 20),

            const Text(
              'Création Compte Admin',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text(
              'Solution simple et rapide',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Identifiants Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.email, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('admin@chafin.com'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Admin123456'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅')
                      ? Colors.green.withOpacity(0.1)
                      : _status.startsWith('❌')
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _status.startsWith('✅')
                        ? Colors.green[800]
                        : _status.startsWith('❌')
                        ? Colors.red[800]
                        : Colors.blue[800],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Bouton de nettoyage
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _cleanupExistingAccount,
              icon: const Icon(Icons.cleaning_services),
              label: const Text(
                'Nettoyer anciens comptes',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bouton principal
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createCleanAdminAccount,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch),
              label: Text(
                _isLoading ? 'Création...' : 'Créer Compte Admin',
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 30),

            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Instructions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Cliquez sur "Nettoyer" pour supprimer l\'ancien\n'
                      '2. Cliquez sur "Créer Compte Admin"\n'
                      '3. Connectez-vous avec admin@chafin.com\n'
                      '4. Interface admin complète !',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
