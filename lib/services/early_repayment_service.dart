import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan_model.dart';
import '../models/payment_schedule_model.dart';

class EarlyRepaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calcule les options de remboursement anticipé pour un prêt
  /// Retourne le nouveau montant mensuel et la nouvelle durée
  EarlyRepaymentOptions calculateEarlyRepaymentOptions({
    required LoanModel loan,
    required double montantAnticipe,
    required int nouvelleDuree,
  }) {
    print('=== CALCUL REMBOURSEMENT ANTICIPÉ ===');
    print('Prêt original:');
    print('- Montant: ${loan.montant}€');
    print('- Durée: ${loan.dureeMois} mois');
    print('- Taux: ${loan.tauxAnnuel}%');
    print('- Mensualité: ${loan.mensualite}€');
    print('- Intérêts totaux: ${loan.coutTotalEstime}€');

    // coutTotalEstime est déjà le montant des intérêts totaux
    final interetsOriginaux = loan.coutTotalEstime;
    print('- Intérêts originaux: ${interetsOriginaux}€');

    print('\nRemboursement anticipé:');
    print('- Montant anticipé: ${montantAnticipe}€');
    print('- Nouvelle durée: ${nouvelleDuree} mois');

    // Le capital restant après le remboursement anticipé
    final capitalRestant = loan.montant - montantAnticipe;
    print('- Capital restant: ${capitalRestant}€');

    // RÈGLE MÉTIER : Garder le même montant d'intérêts total
    // mais le répartir sur la nouvelle durée
    final montantTotalAvecInterets = capitalRestant + interetsOriginaux;
    final nouvelleMensualite = montantTotalAvecInterets / nouvelleDuree;

    print('- Montant total avec intérêts: ${montantTotalAvecInterets}€');
    print('- Nouvelle mensualité: ${nouvelleMensualite}€');

    return EarlyRepaymentOptions(
      montantAnticipe: montantAnticipe,
      capitalRestant: capitalRestant,
      interetsConserves: interetsOriginaux,
      nouvelleDuree: nouvelleDuree,
      nouvelleMensualite: double.parse(nouvelleMensualite.toStringAsFixed(2)),
      montantTotalRestant: double.parse(
        montantTotalAvecInterets.toStringAsFixed(2),
      ),
      economieTemps: loan.dureeMois - nouvelleDuree,
    );
  }

  /// Génère le nouvel échéancier après remboursement anticipé
  List<PaymentScheduleItem> generateNewSchedule({
    required LoanModel loan,
    required EarlyRepaymentOptions options,
    required DateTime dateRemboursement,
  }) {
    print('=== GÉNÉRATION NOUVEL ÉCHÉANCIER ===');

    final List<PaymentScheduleItem> nouvelEcheancier = [];
    final interetsParMois = options.interetsConserves / options.nouvelleDuree;
    final capitalParMois = options.capitalRestant / options.nouvelleDuree;

    print('Répartition mensuelle:');
    print('- Capital par mois: ${capitalParMois}€');
    print('- Intérêts par mois: ${interetsParMois}€');

    double capitalRestantDu = options.capitalRestant;

    for (int i = 1; i <= options.nouvelleDuree; i++) {
      final dateEcheance = DateTime(
        dateRemboursement.year,
        dateRemboursement.month + i,
        dateRemboursement.day,
      );

      // Ajustement pour le dernier mois (gérer les arrondis)
      final montantCapital = i == options.nouvelleDuree
          ? capitalRestantDu
          : double.parse(capitalParMois.toStringAsFixed(2));

      final montantInterets = double.parse(interetsParMois.toStringAsFixed(2));
      capitalRestantDu -= montantCapital;

      nouvelEcheancier.add(
        PaymentScheduleItem(
          numeroEcheance: i,
          dateEcheance: dateEcheance,
          montantCapital: montantCapital,
          montantInterets: montantInterets,
          montantTotal: montantCapital + montantInterets,
          capitalRestantDu: double.parse(capitalRestantDu.toStringAsFixed(2)),
          statut: PaymentStatus.aVenir,
        ),
      );
    }

    print('Nouvel échéancier généré: ${nouvelEcheancier.length} échéances');
    return nouvelEcheancier;
  }

  /// Effectue le remboursement anticipé dans Firebase
  Future<bool> processEarlyRepayment({
    required String loanId,
    required double montantAnticipe,
    required int nouvelleDuree,
    required String userId,
    String? noteUtilisateur,
  }) async {
    try {
      print('=== TRAITEMENT REMBOURSEMENT ANTICIPÉ ===');
      print('Prêt ID: $loanId');
      print('Montant anticipé: ${montantAnticipe}€');
      print('Nouvelle durée: $nouvelleDuree mois');

      // Récupérer le prêt actuel
      final loanDoc = await _firestore.collection('loans').doc(loanId).get();
      if (!loanDoc.exists) {
        throw Exception('Prêt non trouvé');
      }

      final loan = LoanModel.fromJson(loanDoc.data()!);

      // Vérifier que le remboursement anticipé est possible
      if (!loan.allowsEarlyRepayment) {
        throw Exception('Ce prêt ne permet pas le remboursement anticipé');
      }

      if (montantAnticipe >= loan.montant) {
        throw Exception(
          'Le montant anticipé ne peut pas être supérieur ou égal au capital',
        );
      }

      // Calculer les nouvelles conditions
      final options = calculateEarlyRepaymentOptions(
        loan: loan,
        montantAnticipe: montantAnticipe,
        nouvelleDuree: nouvelleDuree,
      );

      final dateRemboursement = DateTime.now();

      // Générer le nouvel échéancier
      final nouvelEcheancier = generateNewSchedule(
        loan: loan,
        options: options,
        dateRemboursement: dateRemboursement,
      );

      // Transaction pour mettre à jour le prêt et l'échéancier
      await _firestore.runTransaction((transaction) async {
        // Mettre à jour le prêt
        final updatedLoan = loan.copyWith(
          dateRemboursementAnticipe: dateRemboursement,
          montantRemboursementAnticipe: montantAnticipe,
          nouvelleDureeMois: nouvelleDuree,
          mensualite: options.nouvelleMensualite,
          updatedAt: DateTime.now(),
        );

        transaction.update(
          _firestore.collection('loans').doc(loanId),
          updatedLoan.toJson(),
        );

        // Sauvegarder le nouvel échéancier
        final scheduleData = {
          'loanId': loanId,
          'echeances': nouvelEcheancier
              .map(
                (item) => {
                  'numeroEcheance': item.numeroEcheance,
                  'dateEcheance': item.dateEcheance.toIso8601String(),
                  'montantCapital': item.montantCapital,
                  'montantInterets': item.montantInterets,
                  'montantTotal': item.montantTotal,
                  'capitalRestantDu': item.capitalRestantDu,
                  'statut': item.statut.toString().split('.').last,
                },
              )
              .toList(),
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'isEarlyRepaymentSchedule': true,
          'originalDuration': loan.dureeMois,
          'newDuration': nouvelleDuree,
          'earlyRepaymentAmount': montantAnticipe,
          'earlyRepaymentDate': dateRemboursement.toIso8601String(),
        };

        transaction.set(
          _firestore.collection('payment_schedules').doc(loanId),
          scheduleData,
        );

        // Enregistrer l'historique du remboursement anticipé
        transaction.set(_firestore.collection('early_repayments').doc(), {
          'loanId': loanId,
          'userId': userId,
          'montantAnticipe': montantAnticipe,
          'ancieneeDuree': loan.dureeMois,
          'nouvelleDuree': nouvelleDuree,
          'ancienneMensualite': loan.mensualite,
          'nouvelleMensualite': options.nouvelleMensualite,
          'interetsConserves': options.interetsConserves,
          'economieTemps': options.economieTemps,
          'dateRemboursement': dateRemboursement.toIso8601String(),
          'noteUtilisateur': noteUtilisateur,
          'createdAt': DateTime.now().toIso8601String(),
        });
      });

      print('Remboursement anticipé traité avec succès');
      return true;
    } catch (e) {
      print('Erreur lors du remboursement anticipé: $e');
      return false;
    }
  }

  /// Récupère l'historique des remboursements anticipés pour un utilisateur
  Future<List<Map<String, dynamic>>> getEarlyRepaymentHistory(
    String userId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('early_repayments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }
}

/// Classe pour représenter les options de remboursement anticipé
class EarlyRepaymentOptions {
  final double montantAnticipe;
  final double capitalRestant;
  final double interetsConserves;
  final int nouvelleDuree;
  final double nouvelleMensualite;
  final double montantTotalRestant;
  final int economieTemps; // En mois

  const EarlyRepaymentOptions({
    required this.montantAnticipe,
    required this.capitalRestant,
    required this.interetsConserves,
    required this.nouvelleDuree,
    required this.nouvelleMensualite,
    required this.montantTotalRestant,
    required this.economieTemps,
  });

  double get economieInterets =>
      0; // Pas d'économie d'intérêts selon les règles métier

  @override
  String toString() {
    return 'EarlyRepaymentOptions(\n'
        '  montantAnticipe: ${montantAnticipe}€\n'
        '  capitalRestant: ${capitalRestant}€\n'
        '  interetsConserves: ${interetsConserves}€\n'
        '  nouvelleDuree: $nouvelleDuree mois\n'
        '  nouvelleMensualite: ${nouvelleMensualite}€\n'
        '  montantTotalRestant: ${montantTotalRestant}€\n'
        '  economieTemps: $economieTemps mois\n'
        ')';
  }
}
