import '../utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service pour gérer les évaluations de risque des clients
class RiskAssessmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Met à jour le niveau de confiance d'un utilisateur
  Future<bool> updateRiskAssessment({
    required String userId,
    required double niveauConfiance,
    required String adminId,
    String? commentaire,
  }) async {
    try {
      // Valider le niveau de confiance (1.0 à 5.0)
      if (niveauConfiance < 1.0 || niveauConfiance > 5.0) {
        throw Exception('Le niveau de confiance doit être entre 1.0 et 5.0');
      }

      // Mettre à jour l'utilisateur
      await _firestore.collection('users').doc(userId).update({
        'niveauConfiance': niveauConfiance,
        'commentaireRisque': commentaire,
        'dernierEvaluationRisque': FieldValue.serverTimestamp(),
        'evaluePar': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Enregistrer l'historique de l'évaluation
      await _logRiskAssessment(
        userId: userId,
        niveauConfiance: niveauConfiance,
        adminId: adminId,
        commentaire: commentaire,
      );

      return true;
    } catch (e) {
      debugLog('❌ Erreur lors de la mise à jour de l\'évaluation de risque: $e');
      return false;
    }
  }

  /// Récupère l'historique des évaluations de risque d'un utilisateur
  Future<List<Map<String, dynamic>>> getRiskAssessmentHistory(
    String userId,
  ) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('risk_assessments')
          .where('userId', isEqualTo: userId)
          .orderBy('evaluatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'niveauConfiance': data['niveauConfiance'],
          'commentaire': data['commentaire'],
          'adminId': data['adminId'],
          'evaluatedAt': (data['evaluatedAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      debugLog('❌ Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  /// Enregistre une évaluation de risque dans l'historique
  Future<void> _logRiskAssessment({
    required String userId,
    required double niveauConfiance,
    required String adminId,
    String? commentaire,
  }) async {
    try {
      await _firestore.collection('risk_assessments').add({
        'userId': userId,
        'niveauConfiance': niveauConfiance,
        'commentaire': commentaire,
        'adminId': adminId,
        'evaluatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugLog('❌ Erreur lors de l\'enregistrement de l\'historique: $e');
      // Ne pas faire échouer la mise à jour si l'historique échoue
    }
  }

  /// Récupère les statistiques des évaluations de risque
  Future<Map<String, dynamic>> getRiskStatistics() async {
    try {
      final QuerySnapshot allUsers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'borrower')
          .get();

      int totalUsers = allUsers.docs.length;
      int evaluatedUsers = 0;
      int faibleRisque = 0;
      int risqueNormal = 0;
      int grosRisque = 0;

      for (final doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final niveauConfiance = data['niveauConfiance']?.toDouble();

        if (niveauConfiance != null) {
          evaluatedUsers++;
          if (niveauConfiance >= 4.0) {
            faibleRisque++;
          } else if (niveauConfiance >= 2.0) {
            risqueNormal++;
          } else {
            grosRisque++;
          }
        }
      }

      return {
        'totalUsers': totalUsers,
        'evaluatedUsers': evaluatedUsers,
        'nonEvaluatedUsers': totalUsers - evaluatedUsers,
        'faibleRisque': faibleRisque,
        'risqueNormal': risqueNormal,
        'grosRisque': grosRisque,
        'evaluationRate': totalUsers > 0
            ? (evaluatedUsers / totalUsers * 100)
            : 0.0,
      };
    } catch (e) {
      debugLog('❌ Erreur lors du calcul des statistiques: $e');
      return {};
    }
  }

  /// Détermine le niveau de risque textuel
  static String getRiskLevelText(double? niveauConfiance) {
    if (niveauConfiance == null) return 'Non évalué';
    if (niveauConfiance >= 4.0) return 'Faible risque';
    if (niveauConfiance >= 2.0) return 'Risque normal';
    return 'Gros risque';
  }

  /// Détermine la couleur associée au niveau de risque
  static String getRiskLevelColor(double? niveauConfiance) {
    if (niveauConfiance == null) return 'grey';
    if (niveauConfiance >= 4.0) return 'green';
    if (niveauConfiance >= 2.0) return 'orange';
    return 'red';
  }
}
