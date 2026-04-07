import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';

class DebugDataScreen extends StatefulWidget {
  const DebugDataScreen({super.key});

  @override
  State<DebugDataScreen> createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends State<DebugDataScreen> {
  String _debugInfo = 'Chargement des infos debug...';

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final loanProvider = Provider.of<LoanProvider>(context, listen: false);

      String info = '=== DEBUG INFO ===\n\n';

      // Info utilisateur
      info += '📱 UTILISATEUR:\n';
      if (authProvider.currentUser != null) {
        final user = authProvider.currentUser!;
        info += '- ID: ${user.id}\n';
        info += '- Email: ${user.email}\n';
        info += '- Nom: ${user.nom}\n';
        info += '- Admin: ${user.isAdmin}\n';
      } else {
        info += '- AUCUN UTILISATEUR CONNECTÉ\n';
      }

      info += '\n💼 PRÊTS DANS LE PROVIDER:\n';
      info += '- Nombre: ${loanProvider.userLoans.length}\n';
      info += '- Loading: ${loanProvider.isLoading}\n';
      info += '- Error: ${loanProvider.errorMessage ?? "Aucune"}\n';

      // Info Firestore directe
      info += '\n🔥 FIREBASE DIRECT:\n';
      try {
        final loansCollection = FirebaseFirestore.instance.collection('loans');
        final allLoansSnapshot = await loansCollection.get();
        info +=
            '- Total documents dans loans: ${allLoansSnapshot.docs.length}\n';

        if (authProvider.currentUser != null) {
          final userLoansSnapshot = await loansCollection
              .where('userId', isEqualTo: authProvider.currentUser!.id)
              .get();
          info +=
              '- Prêts pour userId ${authProvider.currentUser!.id}: ${userLoansSnapshot.docs.length}\n';

          for (final doc in userLoansSnapshot.docs) {
            final data = doc.data();
            info +=
                '  * Doc ${doc.id}: userId=${data['userId']}, montant=${data['montant']}\n';
          }
        }

        // Afficher tous les userIds distincts
        final allUserIds = allLoansSnapshot.docs
            .map((doc) => doc.data()['userId'] as String?)
            .where((id) => id != null)
            .toSet();
        info += '- UserIds distincts trouvés: ${allUserIds.join(", ")}\n';
      } catch (e) {
        info += '- Erreur Firestore: $e\n';
      }

      setState(() {
        _debugInfo = info;
      });
    } catch (e) {
      setState(() {
        _debugInfo = 'Erreur debug: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Données'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                _debugInfo,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final loanProvider = Provider.of<LoanProvider>(
                  context,
                  listen: false,
                );
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                if (authProvider.currentUser != null) {
                  loanProvider.loadUserLoans(authProvider.currentUser!.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rechargement des prêts...')),
                  );
                }
              },
              child: const Text('Recharger les prêts'),
            ),
          ],
        ),
      ),
    );
  }
}
