import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FixAdminScreen extends StatefulWidget {
  const FixAdminScreen({super.key});

  @override
  State<FixAdminScreen> createState() => _FixAdminScreenState();
}

class _FixAdminScreenState extends State<FixAdminScreen> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _fixAdminRole() async {
    setState(() {
      _isLoading = true;
      _status = 'Recherche du compte admin@chafin.com...';
    });

    try {
      // Rechercher le document par email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'admin@chafin.com')
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _status = '❌ Aucun compte trouvé avec admin@chafin.com';
          _isLoading = false;
        });
        return;
      }

      final userDoc = querySnapshot.docs.first;
      final userId = userDoc.id;

      setState(() {
        _status = 'Mise à jour du rôle vers admin...';
      });

      // Mettre à jour le rôle
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': 'admin',
        'nom': 'Administrateur Chafin',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      setState(() {
        _status = '✅ Compte admin@chafin.com mis à jour avec succès !';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rôle admin mis à jour ! Reconnectez-vous avec admin@chafin.com',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '❌ Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Correction Rôle Admin'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.build, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              'Correction Compte Admin',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Met à jour le rôle du compte existant',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅')
                      ? Colors.green.withOpacity(0.1)
                      : _status.startsWith('❌')
                      ? Colors.red.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
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
                        : Colors.orange[800],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fixAdminRole,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build),
              label: Text(
                _isLoading ? 'Correction...' : 'Corriger Rôle Admin',
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                      'Le problème détecté',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Un compte admin@chafin.com existe mais avec le rôle "borrower".\n'
                      'Cette correction va changer le rôle vers "admin".',
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
