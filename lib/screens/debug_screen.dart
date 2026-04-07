import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_initializer.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _log = '';
  bool _isLoading = false;

  void _addToLog(String message) {
    setState(() {
      _log += '${DateTime.now().toString().substring(11, 19)} - $message\n';
    });
    print(message);
  }

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _isLoading = true;
      _log = '';
    });

    _addToLog('🔄 Test de connexion Firebase...');

    try {
      // Test Firebase Auth
      final auth = FirebaseAuth.instance;
      _addToLog('✅ Firebase Auth connecté');
      _addToLog('👤 Utilisateur actuel: ${auth.currentUser?.email ?? "Aucun"}');

      // Test Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('test').doc('connection').set({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'connected',
      });
      _addToLog('✅ Firestore connecté - Document de test créé');

      // Lire le document de test
      final testDoc = await firestore
          .collection('test')
          .doc('connection')
          .get();
      if (testDoc.exists) {
        _addToLog('✅ Lecture Firestore réussie');
      }

      // Supprimer le document de test
      await firestore.collection('test').doc('connection').delete();
      _addToLog('✅ Suppression test réussie');
    } catch (e) {
      _addToLog('❌ Erreur de connexion: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initializeTestData() async {
    setState(() {
      _isLoading = true;
    });

    _addToLog('🔄 Initialisation des données de test...');

    try {
      await FirebaseInitializer.initializeTestData();
      _addToLog('✅ Données de test initialisées');
      _addToLog('📧 Admin: admin@chafin.com / admin123');
      _addToLog('📧 Emprunteur: emprunteur@test.com / test123');
    } catch (e) {
      _addToLog('❌ Erreur initialisation: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _clearTestData() async {
    setState(() {
      _isLoading = true;
    });

    _addToLog('🔄 Suppression des données de test...');

    try {
      await FirebaseInitializer.clearTestData();
      _addToLog('✅ Données supprimées');
    } catch (e) {
      _addToLog('❌ Erreur suppression: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      _addToLog('✅ Déconnexion réussie');
    } catch (e) {
      _addToLog('❌ Erreur déconnexion: $e');
    }
  }

  Future<void> _listUsers() async {
    setState(() {
      _isLoading = true;
    });

    _addToLog('🔄 Liste des utilisateurs...');

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      if (snapshot.docs.isEmpty) {
        _addToLog('ℹ️  Aucun utilisateur trouvé');
      } else {
        _addToLog('👥 ${snapshot.docs.length} utilisateur(s) trouvé(s):');
        for (final doc in snapshot.docs) {
          final data = doc.data();
          _addToLog('   • ${data['nom']} (${data['email']}) - ${data['role']}');
        }
      }
    } catch (e) {
      _addToLog('❌ Erreur lecture users: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Firebase'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Boutons d'action
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testFirebaseConnection,
                  child: const Text('Test Connexion'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _initializeTestData,
                  child: const Text('Init Données Test'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _listUsers,
                  child: const Text('Liste Utilisateurs'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _clearTestData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Vider Données'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signOut,
                  child: const Text('Déconnexion'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Zone de log
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log.isEmpty ? 'Prêt pour les tests...' : _log,
                    style: const TextStyle(
                      color: Colors.green,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
