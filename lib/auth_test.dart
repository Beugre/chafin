import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialisé avec succès');
  } catch (e) {
    print('❌ Erreur Firebase: $e');
  }

  runApp(const AuthTestApp());
}

class AuthTestApp extends StatelessWidget {
  const AuthTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Auth Test', home: AuthTestScreen());
  }
}

class AuthTestScreen extends StatefulWidget {
  const AuthTestScreen({super.key});

  @override
  _AuthTestScreenState createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends State<AuthTestScreen> {
  String _status = 'Initializing...';
  final _emailController = TextEditingController(text: 'test@example.com');
  final _passwordController = TextEditingController(text: 'password123');

  @override
  void initState() {
    super.initState();
    _checkFirebaseAuth();
  }

  void _checkFirebaseAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      // Vérification que Firestore est accessible sans variable non utilisée
      FirebaseFirestore.instance;

      setState(() {
        _status = '✅ Firebase Auth et Firestore accessibles\n';
        _status +=
            'Utilisateur actuel: ${auth.currentUser?.email ?? "Aucun"}\n';
        _status += 'Project ID: ${Firebase.app().options.projectId}\n';
        _status += 'Auth Domain: ${Firebase.app().options.authDomain}\n\n';
        _status += 'Prêt pour les tests d\'authentification';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Erreur Firebase: $e';
      });
    }
  }

  void _testCreateUser() async {
    try {
      setState(() {
        _status = '🔄 Création d\'utilisateur en cours...';
      });

      final auth = FirebaseAuth.instance;
      final email = _emailController.text;
      final password = _passwordController.text;

      print('=== TEST CRÉATION UTILISATEUR ===');
      print('Email: $email');
      print('Password length: ${password.length}');

      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      setState(() {
        _status = '✅ Utilisateur créé avec succès!\n';
        _status += 'UID: ${credential.user?.uid}\n';
        _status += 'Email: ${credential.user?.email}\n';
        _status += 'Vérifié: ${credential.user?.emailVerified}';
      });

      // Maintenant on teste Firestore
      _testFirestore(credential.user!.uid, email);
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      setState(() {
        _status = '❌ Erreur Auth Firebase:\n';
        _status += 'Code: ${e.code}\n';
        _status += 'Message: ${e.message}\n\n';
        _status += _getAuthErrorHelp(e.code);
      });
    } catch (e) {
      print('Exception générale: $e');
      setState(() {
        _status = '❌ Erreur générale: $e';
      });
    }
  }

  void _testFirestore(String uid, String email) async {
    try {
      setState(() {
        _status += '\n\n🔄 Test Firestore...';
      });

      final firestore = FirebaseFirestore.instance;

      // Créer un document utilisateur
      await firestore.collection('users').doc(uid).set({
        'email': email,
        'nom': 'Test User',
        'telephone': '+33123456789',
        'adresse': '123 Test Street',
        'role': 'borrower',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status += '\n✅ Document Firestore créé avec succès!';
      });
    } catch (e) {
      setState(() {
        _status += '\n❌ Erreur Firestore: $e';
      });
    }
  }

  void _testSignIn() async {
    try {
      setState(() {
        _status = '🔄 Connexion en cours...';
      });

      final auth = FirebaseAuth.instance;
      final credential = await auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      setState(() {
        _status = '✅ Connexion réussie!\n';
        _status += 'UID: ${credential.user?.uid}\n';
        _status += 'Email: ${credential.user?.email}';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = '❌ Erreur de connexion:\n';
        _status += 'Code: ${e.code}\n';
        _status += 'Message: ${e.message}';
      });
    }
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _status = '✅ Déconnexion réussie';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Erreur de déconnexion: $e';
      });
    }
  }

  String _getAuthErrorHelp(String errorCode) {
    switch (errorCode) {
      case 'configuration-not-found':
        return '''💡 SOLUTION:
1. Allez sur Firebase Console
2. Authentication > Sign-in method
3. Activez Email/Password
4. Vérifiez les domaines autorisés''';
      case 'auth/invalid-api-key':
        return '''💡 SOLUTION:
Clé API invalide. Reconfigurer:
flutterfire configure''';
      case 'auth/project-not-found':
        return '''💡 SOLUTION:
Projet non trouvé. Vérifiez:
- Project ID dans firebase_options.dart
- Permissions du projet''';
      default:
        return '💡 Consultez: https://firebase.google.com/docs/auth/web/start';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Auth Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey),
              ),
              child: Text(
                _status,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),

            const SizedBox(height: 20),

            // Email field
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            // Password field
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),

            const SizedBox(height: 20),

            // Buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: _testCreateUser,
                  child: const Text('Créer Utilisateur'),
                ),
                ElevatedButton(
                  onPressed: _testSignIn,
                  child: const Text('Se Connecter'),
                ),
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Se Déconnecter'),
                ),
                ElevatedButton(
                  onPressed: _checkFirebaseAuth,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Vérifier Config'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
