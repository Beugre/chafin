import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/loan_model.dart';
import '../models/repayment_model.dart';

class RepaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Générer l'échéancier pour un prêt approuvé
  Future<void> generateRepaymentSchedule(LoanModel loan) async {
    try {
      print('=== RepaymentService.generateRepaymentSchedule ===');
      print(
        'Prêt ID: ${loan.id}, Montant: ${loan.montant}€, Durée: ${loan.dureeMois} mois',
      );

      // Vérifier s'il existe déjà un échéancier pour ce prêt
      final existingRepayments = await getLoanRepayments(loan.id);
      if (existingRepayments.isNotEmpty) {
        print(
          'Échéancier déjà existant (${existingRepayments.length} mensualités)',
        );
        return;
      }

      // Calculer la date de premier remboursement (1 mois après décaissement)
      final DateTime premierRemboursement = loan.disbursedAt ?? DateTime.now();
      final DateTime dateDebutRemboursement = DateTime(
        premierRemboursement.year,
        premierRemboursement.month + 1,
        premierRemboursement.day,
      );

      print('Date début remboursements: $dateDebutRemboursement');

      final List<RepaymentModel> mensualites = [];

      // Créer chaque mensualité
      for (int i = 1; i <= loan.dureeMois; i++) {
        final DateTime dateEcheance = DateTime(
          dateDebutRemboursement.year,
          dateDebutRemboursement.month + (i - 1),
          dateDebutRemboursement.day,
        );

        final mensualite = RepaymentModel(
          id: _uuid.v4(),
          loanId: loan.id,
          userId: loan.userId,
          numeroMensualite: i,
          montantDu: loan.mensualite,
          dateEcheance: dateEcheance,
          createdAt: DateTime.now(),
        );

        mensualites.add(mensualite);
      }

      print('Échéancier généré: ${mensualites.length} mensualités');

      // Sauvegarder toutes les mensualités en batch
      final WriteBatch batch = _firestore.batch();

      for (final mensualite in mensualites) {
        final docRef = _firestore.collection('repayments').doc(mensualite.id);
        batch.set(docRef, mensualite.toJson());
      }

      await batch.commit();
      print('Échéancier sauvegardé avec succès');
    } catch (e) {
      print('Erreur génération échéancier: $e');
      throw Exception('Erreur lors de la génération de l\'échéancier: $e');
    }
  }

  /// Récupérer l'échéancier d'un prêt
  Future<List<RepaymentModel>> getLoanRepayments(String loanId) async {
    try {
      print('=== RepaymentService.getLoanRepayments ===');
      print('Prêt ID: $loanId');

      final QuerySnapshot snapshot = await _firestore
          .collection('repayments')
          .where('loanId', isEqualTo: loanId)
          .orderBy('numeroMensualite', descending: false)
          .get();

      final repayments = snapshot.docs
          .map(
            (doc) =>
                RepaymentModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();

      print('Mensualités trouvées: ${repayments.length}');

      return repayments;
    } catch (e) {
      print('Erreur récupération échéancier: $e');
      throw Exception('Erreur lors de la récupération de l\'échéancier: $e');
    }
  }

  /// Marquer une mensualité comme payée
  Future<void> markRepaymentAsPaid(
    String repaymentId,
    double montantPaye, {
    String? referencePaiement,
    String? noteAdmin,
  }) async {
    try {
      print('=== RepaymentService.markRepaymentAsPaid ===');
      print('Mensualité ID: $repaymentId, Montant: $montantPaye€');

      await _firestore.collection('repayments').doc(repaymentId).update({
        'montantPaye': montantPaye,
        'datePaiement': DateTime.now().toIso8601String(),
        'statut': RepaymentStatus.paye.toString().split('.').last,
        'updatedAt': DateTime.now().toIso8601String(),
        'referencePaiement': referencePaiement,
        'noteAdmin': noteAdmin,
      });

      print('Mensualité marquée comme payée');

      // Vérifier si toutes les mensualités du prêt sont payées
      await _checkLoanCompletionStatus(repaymentId);
    } catch (e) {
      print('Erreur marquage paiement: $e');
      throw Exception('Erreur lors du marquage du paiement: $e');
    }
  }

  /// Vérifier si le prêt est complètement remboursé
  Future<void> _checkLoanCompletionStatus(String repaymentId) async {
    try {
      // Récupérer la mensualité pour avoir le loanId
      final repaymentDoc = await _firestore
          .collection('repayments')
          .doc(repaymentId)
          .get();

      if (!repaymentDoc.exists) return;

      final repayment = RepaymentModel.fromJson(repaymentDoc.data()!);
      final loanId = repayment.loanId;

      // Récupérer toutes les mensualités du prêt
      final allRepayments = await getLoanRepayments(loanId);

      // Vérifier si toutes sont payées
      final bool allPaid = allRepayments.every((r) => r.isPaid);

      if (allPaid) {
        print('Toutes les mensualités sont payées, prêt soldé');

        // Mettre à jour le statut du prêt
        await _firestore.collection('loans').doc(loanId).update({
          'statut': LoanStatus.solde.toString().split('.').last,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        // Vérifier si le prêt était en retard et si les retards sont réglés
        final loanDoc = await _firestore.collection('loans').doc(loanId).get();
        if (loanDoc.exists) {
          final loanData = loanDoc.data()!;
          final currentStatus = loanData['statut'] as String?;
          
          // Si le prêt est marqué "enRetard", vérifier s'il y a encore des retards
          if (currentStatus == LoanStatus.enRetard.toString().split('.').last) {
            final now = DateTime.now();
            final hasOverdueRepayments = allRepayments.any((r) => 
              !r.isPaid && r.dateEcheance.isBefore(now)
            );
            
            // S'il n'y a plus de retards, repasser le prêt "enCours"
            if (!hasOverdueRepayments) {
              print('Plus de retards, prêt repassé en cours');
              await _firestore.collection('loans').doc(loanId).update({
                'statut': LoanStatus.enCours.toString().split('.').last,
                'updatedAt': DateTime.now().toIso8601String(),
              });
            }
          }
        }
      }
    } catch (e) {
      print('Erreur vérification statut prêt: $e');
    }
  }

  /// Récupérer tous les remboursements d'un utilisateur
  Future<List<RepaymentModel>> getUserRepayments(String userId) async {
    try {
      print('=== RepaymentService.getUserRepayments ===');
      print('User ID: $userId');

      // Requête sans orderBy pour éviter l'erreur d'index
      final QuerySnapshot snapshot = await _firestore
          .collection('repayments')
          .where('userId', isEqualTo: userId)
          .get();

      final repayments = snapshot.docs
          .map(
            (doc) =>
                RepaymentModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();

      // Trier en mémoire par date d'échéance
      repayments.sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));

      print('Mensualités utilisateur: ${repayments.length}');

      return repayments;
    } catch (e) {
      print('Erreur récupération mensualités utilisateur: $e');
      throw Exception('Erreur lors de la récupération des mensualités: $e');
    }
  }

  /// Récupérer les mensualités en retard
  Future<List<RepaymentModel>> getOverdueRepayments() async {
    try {
      print('=== RepaymentService.getOverdueRepayments ===');

      final DateTime now = DateTime.now();

      final QuerySnapshot snapshot = await _firestore
          .collection('repayments')
          .where(
            'statut',
            isEqualTo: RepaymentStatus.enAttente.toString().split('.').last,
          )
          .get();

      final allPending = snapshot.docs
          .map(
            (doc) =>
                RepaymentModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();

      // Filtrer celles en retard
      final overdue = allPending
          .where((repayment) => repayment.dateEcheance.isBefore(now))
          .toList();

      print('Mensualités en retard: ${overdue.length}');

      // Marquer automatiquement comme en retard si nécessaire
      for (final repayment in overdue) {
        if (repayment.statut != RepaymentStatus.enRetard) {
          await _firestore.collection('repayments').doc(repayment.id).update({
            'statut': RepaymentStatus.enRetard.toString().split('.').last,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }

      return overdue;
    } catch (e) {
      print('Erreur récupération retards: $e');
      throw Exception('Erreur lors de la récupération des retards: $e');
    }
  }
}
