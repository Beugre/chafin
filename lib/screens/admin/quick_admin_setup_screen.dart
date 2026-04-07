import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuickAdminSetupScreen extends StatefulWidget {
  const QuickAdminSetupScreen({super.key});

  @override
  State<QuickAdminSetupScreen> createState() => _QuickAdminSetupScreenState();
}

class _QuickAdminSetupScreenState extends State<QuickAdminSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'admin@chafin.com');
  final _passwordController = TextEditingController(text: 'Admin123456');
  bool _isLoading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Admin Rapide'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 64,
                color: Colors.blue[800],
              ),
              const SizedBox(height: 24),
              Text(
                'Création Compte Admin',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Admin',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir un email';
                  }
                  if (!value.contains('@')) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir un mot de passe';
                  }
                  if (value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createAdminAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Créer Compte Admin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _message!.startsWith('Erreur')
                        ? Colors.red[100]
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _message!.startsWith('Erreur')
                          ? Colors.red[800]
                          : Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Créez le compte admin avec les identifiants ci-dessus',
                      ),
                      Text('2. Utilisez ces identifiants pour vous connecter'),
                      Text('3. Accédez au tableau de bord admin complet'),
                      SizedBox(height: 8),
                      Text(
                        'Note: Cette méthode évite les problèmes de timestamp',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAdminAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      print('🚀 Début création compte admin...');
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Créer le compte utilisateur
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final userId = userCredential.user!.uid;
      print('✅ Compte Firebase créé: $userId');

      // Créer le document utilisateur avec structure propre (pas de Timestamp)
      final userData = {
        'id': userId,
        'email': email,
        'firstName': 'Admin',
        'lastName': 'System',
        'role': 'admin',
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(), // Format string simple
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData);

      print('✅ Document utilisateur créé dans Firestore');
      print('📄 Données: $userData');

      setState(() {
        _message =
            'Compte admin créé avec succès ! Vous pouvez maintenant vous connecter.';
      });

      // Déconnecter l'utilisateur créé pour permettre la connexion normale
      await FirebaseAuth.instance.signOut();
      print('✅ Déconnexion automatique effectuée');
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur FirebaseAuth: ${e.code} - ${e.message}');
      String errorMessage = 'Erreur lors de la création du compte';

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Un compte avec cet email existe déjà';
          break;
        case 'weak-password':
          errorMessage = 'Le mot de passe est trop faible';
          break;
        case 'invalid-email':
          errorMessage = 'Email invalide';
          break;
        default:
          errorMessage = 'Erreur: ${e.message}';
      }

      setState(() {
        _message = errorMessage;
      });
    } catch (e) {
      print('❌ Erreur générale: $e');
      setState(() {
        _message = 'Erreur inattendue: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
