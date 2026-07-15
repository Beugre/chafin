import '../utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Nettoyer les échéanciers dupliqués
  Future<void> cleanupDuplicateRepayments() async {
    try {
      debugLog('=== CleanupService.cleanupDuplicateRepayments ===');

      // Récupérer tous les remboursements
      final QuerySnapshot allRepayments = await _firestore
          .collection('repayments')
          .get();

      // Grouper par loanId
      final Map<String, List<QueryDocumentSnapshot>> loanRepayments = {};

      for (final doc in allRepayments.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final loanId = data['loanId'] as String;

        if (!loanRepayments.containsKey(loanId)) {
          loanRepayments[loanId] = [];
        }
        loanRepayments[loanId]!.add(doc);
      }

      // Traiter chaque prêt
      for (final entry in loanRepayments.entries) {
        final loanId = entry.key;
        final repayments = entry.value;

        if (repayments.length <= 12) {
          debugLog('Prêt $loanId: ${repayments.length} mensualités - OK');
          continue;
        }

        debugLog(
          'Prêt $loanId: ${repayments.length} mensualités - NETTOYAGE REQUIS',
        );

        // Grouper par numéro de mensualité
        final Map<int, List<QueryDocumentSnapshot>> byMonth = {};

        for (final doc in repayments) {
          final data = doc.data() as Map<String, dynamic>;
          final month = data['numeroMensualite'] as int;

          if (!byMonth.containsKey(month)) {
            byMonth[month] = [];
          }
          byMonth[month]!.add(doc);
        }

        // Nettoyer les doublons
        final WriteBatch batch = _firestore.batch();
        int deletedCount = 0;

        for (final monthEntry in byMonth.entries) {
          final monthlyRepayments = monthEntry.value;

          if (monthlyRepayments.length > 1) {
            // Garder la première mensualité (ou celle qui est payée)
            QueryDocumentSnapshot? toKeep;

            // Chercher une mensualité payée en priorité
            for (final doc in monthlyRepayments) {
              final data = doc.data() as Map<String, dynamic>;
              final statut = data['statut'] as String?;

              if (statut == 'paye') {
                toKeep = doc;
                break;
              }
            }

            // Si aucune n'est payée, garder la première
            toKeep ??= monthlyRepayments.first;

            // Supprimer les autres
            for (final doc in monthlyRepayments) {
              if (doc.id != toKeep.id) {
                batch.delete(doc.reference);
                deletedCount++;
                debugLog(
                  '  Suppression mensualité ${monthEntry.key} (ID: ${doc.id})',
                );
              }
            }
          }
        }

        if (deletedCount > 0) {
          await batch.commit();
          debugLog(
            'Prêt $loanId: $deletedCount mensualités dupliquées supprimées',
          );
        }
      }

      debugLog('Nettoyage terminé');
    } catch (e) {
      debugLog('Erreur nettoyage: $e');
      throw Exception('Erreur lors du nettoyage: $e');
    }
  }

  /// Nettoyer un prêt spécifique
  Future<void> cleanupLoanRepayments(String loanId) async {
    try {
      debugLog('=== CleanupService.cleanupLoanRepayments ===');
      debugLog('Nettoyage prêt: $loanId');

      final QuerySnapshot repayments = await _firestore
          .collection('repayments')
          .where('loanId', isEqualTo: loanId)
          .get();

      if (repayments.docs.isEmpty) {
        debugLog('Aucune mensualité trouvée');
        return;
      }

      debugLog('Mensualités trouvées: ${repayments.docs.length}');

      // Grouper par numéro de mensualité
      final Map<int, List<QueryDocumentSnapshot>> byMonth = {};

      for (final doc in repayments.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final month = data['numeroMensualite'] as int;

        if (!byMonth.containsKey(month)) {
          byMonth[month] = [];
        }
        byMonth[month]!.add(doc);
      }

      // Nettoyer les doublons
      final WriteBatch batch = _firestore.batch();
      int deletedCount = 0;

      for (final monthEntry in byMonth.entries) {
        final monthlyRepayments = monthEntry.value;

        if (monthlyRepayments.length > 1) {
          debugLog(
            'Mensualité ${monthEntry.key}: ${monthlyRepayments.length} doublons',
          );

          // Garder la première mensualité (ou celle qui est payée)
          QueryDocumentSnapshot? toKeep;

          // Chercher une mensualité payée en priorité
          for (final doc in monthlyRepayments) {
            final data = doc.data() as Map<String, dynamic>;
            final statut = data['statut'] as String?;

            if (statut == 'paye') {
              toKeep = doc;
              debugLog('  Garde mensualité payée: ${doc.id}');
              break;
            }
          }

          // Si aucune n'est payée, garder la première
          if (toKeep == null) {
            toKeep = monthlyRepayments.first;
            debugLog('  Garde première mensualité: ${toKeep.id}');
          }

          // Supprimer les autres
          for (final doc in monthlyRepayments) {
            if (doc.id != toKeep.id) {
              batch.delete(doc.reference);
              deletedCount++;
              debugLog('  Supprime: ${doc.id}');
            }
          }
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        debugLog('$deletedCount mensualités dupliquées supprimées');
      } else {
        debugLog('Aucun doublon trouvé');
      }
    } catch (e) {
      debugLog('Erreur nettoyage prêt: $e');
      throw Exception('Erreur lors du nettoyage du prêt: $e');
    }
  }
}
