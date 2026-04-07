import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  runApp(const FirebaseTestApp());
}

class FirebaseTestApp extends StatelessWidget {
  const FirebaseTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Firebase Test',
      home: FirebaseTestScreen(),
    );
  }
}

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  _FirebaseTestScreenState createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String _status = 'Testing Firebase...';

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  void _testFirebase() async {
    try {
      final auth = FirebaseAuth.instance;
      setState(() {
        _status =
            '✅ Firebase Auth accessible\nUser: ${auth.currentUser?.email ?? "None"}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Firebase Error: $e';
      });
    }
  }

  void _testSignUp() async {
    try {
      setState(() {
        _status = 'Testing sign up...';
      });

      final auth = FirebaseAuth.instance;
      final credential = await auth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      setState(() {
        _status = '✅ Sign up successful: ${credential.user?.uid}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Sign up failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_status),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testSignUp,
              child: const Text('Test Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
