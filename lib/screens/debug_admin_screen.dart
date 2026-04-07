import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class DebugAdminScreen extends StatefulWidget {
  const DebugAdminScreen({super.key});

  @override
  State<DebugAdminScreen> createState() => _DebugAdminScreenState();
}

class _DebugAdminScreenState extends State<DebugAdminScreen> {
  bool _isLoading = false;

  Future<void> _fixTimestampIssue() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      print('=== Correction des timestamps ===');

      // Récupérer le document actuel
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // Convertir tous les timestamps en DateTime ISO strings
        final Map<String, dynamic> cleanedData = {};

        for (final entry in data.entries) {
          if (entry.value is Timestamp) {
            cleanedData[entry.key] = (entry.value as Timestamp)
                .toDate()
                .toIso8601String();
          } else {
            cleanedData[entry.key] = entry.value;
          }
        }

        // Mettre à jour avec les données nettoyées
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .set(cleanedData);

        print('✅ Timestamps corrigés !');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Timestamps corrigés ! Vous pouvez maintenant vous reconnecter.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur correction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _makeCurrentUserAdmin() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      print('=== Transformation en admin ===');
      print('User ID: ${currentUser.id}');
      print('Email: ${currentUser.email}');

      // Mettre à jour le document Firestore avec le rôle admin
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .update({
            'role': UserRole.admin.name,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      // Les modifications seront prises en compte au prochain démarrage

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compte transformé en admin avec succès ! Redémarrez l\'app.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      print('✅ Transformation réussie !');
    } catch (e) {
      print('❌ Erreur: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Admin'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.currentUser;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Utilisateur Actuel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (user != null) ...[
                          Text('ID: ${user.id}'),
                          Text('Email: ${user.email}'),
                          Text('Nom: ${user.nom}'),
                          Text('Rôle actuel: ${user.role}'),
                          const SizedBox(height: 16),
                          if (user.role != UserRole.admin) ...[
                            const Text(
                              '⚠️ Cet utilisateur n\'est pas admin.',
                              style: TextStyle(color: Colors.orange),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _makeCurrentUserAdmin,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.admin_panel_settings),
                                label: Text(
                                  _isLoading
                                      ? 'Transformation...'
                                      : 'Transformer en Admin',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ] else ...[
                            const Text(
                              '✅ Cet utilisateur est déjà admin !',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ] else ...[
                          const Text('Aucun utilisateur connecté'),
                        ],

                        // Bouton de correction des timestamps
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          'Problème de timestamps ?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Si vous avez une erreur "timestamp it\'s not a type string", cliquez ici :',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _fixTimestampIssue,
                            icon: const Icon(Icons.healing),
                            label: const Text('Corriger les Timestamps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('1. Cliquez sur "Transformer en Admin"'),
                        Text('2. Attendez la confirmation'),
                        Text('3. Redémarrez l\'application (hot restart)'),
                        Text('4. Vous serez redirigé vers l\'interface admin'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
