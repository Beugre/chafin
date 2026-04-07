import '../models/payment_schedule_model.dart';

class PaymentScheduleService {
  /// Génère l'échéancier avec TAUX SIMPLE pour un prêt
  /// Calculs directs pour éviter les erreurs d'arrondi
  static PaymentSchedule generateSchedule({
    required String loanId,
    required double montantPret,
    required int dureeMois,
    required double tauxAnnuel,
    required DateTime dateDecaissement,
  }) {
    // TAUX SIMPLE : calculs exacts pour éviter les erreurs d'arrondi
    final interetsTotaux = montantPret * (tauxAnnuel / 100);

    // Calculs mensuels avec arrondis cohérents (83€ et 17€)
    final interetsMensuelExact = interetsTotaux / dureeMois;
    final capitalMensuelExact = montantPret / dureeMois;

    // Arrondis standard pour uniformité avec "Voir tout"
    final capitalMensuelArrondi = (capitalMensuelExact).round().toDouble();
    final interetsMensuelArrondi = (interetsMensuelExact).round().toDouble();

    final List<PaymentScheduleItem> echeances = [];
    double capitalRestant = montantPret;
    double capitalTotalRembourse = 0;
    double interetsTotalPayes = 0;

    for (int mois = 1; mois <= dureeMois; mois++) {
      // Utiliser des arrondis cohérents avec "Voir tout"
      double capitalCeMois, interetsCeMois;

      if (mois == dureeMois) {
        // Dernière échéance : ajuster pour que le total soit exact
        capitalCeMois = montantPret - capitalTotalRembourse;
        interetsCeMois = interetsTotaux - interetsTotalPayes;
      } else {
        // Échéances normales : utiliser les arrondis cohérents
        capitalCeMois = capitalMensuelArrondi;
        interetsCeMois = interetsMensuelArrondi;
      }

      // Calculer le capital restant APRÈS ce paiement
      capitalTotalRembourse += capitalCeMois;
      interetsTotalPayes += interetsCeMois;
      capitalRestant = montantPret - capitalTotalRembourse;

      // S'assurer que le capital restant ne devient pas négatif (dernière échéance)
      if (mois == dureeMois) {
        capitalRestant = 0;
      }

      // Date d'échéance
      final dateEcheance = DateTime(
        dateDecaissement.year,
        dateDecaissement.month + mois,
        dateDecaissement.day,
      );

      echeances.add(
        PaymentScheduleItem(
          numeroEcheance: mois,
          dateEcheance: dateEcheance,
          montantCapital: double.parse(capitalCeMois.toStringAsFixed(2)),
          montantInterets: double.parse(interetsCeMois.toStringAsFixed(2)),
          montantTotal: double.parse(
            (capitalCeMois + interetsCeMois).toStringAsFixed(2),
          ),
          capitalRestantDu: double.parse(capitalRestant.toStringAsFixed(2)),
        ),
      );
    }

    return PaymentSchedule(
      loanId: loanId,
      echeances: echeances,
      createdAt: DateTime.now(),
    );
  }

  /// Calcule les statistiques de l'échéancier
  static Map<String, double> calculateScheduleStats(PaymentSchedule schedule) {
    final totalCapital = schedule.totalCapital;
    final totalInterets = schedule.totalInterets;
    final totalMontant = schedule.totalMontant;

    return {
      'totalCapital': totalCapital,
      'totalInterets': totalInterets,
      'totalMontant': totalMontant,
      'pourcentageInterets': (totalInterets / totalMontant) * 100,
    };
  }

  /// Simule les paiements pour les tests
  static PaymentSchedule simulatePayments(
    PaymentSchedule schedule,
    int nombrePaiements,
  ) {
    final echeancesMisesAJour = schedule.echeances.map((echeance) {
      if (echeance.numeroEcheance <= nombrePaiements) {
        return echeance.copyWith(
          statut: PaymentStatus.payee,
          datePaiement: echeance.dateEcheance,
          montantPaye: echeance.montantTotal,
        );
      }
      return echeance;
    }).toList();

    return PaymentSchedule(
      loanId: schedule.loanId,
      echeances: echeancesMisesAJour,
      createdAt: schedule.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
