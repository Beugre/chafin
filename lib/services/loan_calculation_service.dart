import '../models/schedule_item_model.dart';
import '../utils/constants.dart';

class LoanCalculationService {
  /// VRAIE RÈGLE MÉTIER : Calcule le taux d'intérêt selon la durée uniquement
  /// - 1 mois (remboursement en une fois) => 5%
  /// - 2 à 4 mensualités => 10%
  /// - 5 à 8 mensualités => 15%
  /// - 9 mensualités et + => 20%
  static double calculateTauxSelonDuree(int dureeMois) {
    if (dureeMois <= 0) {
      return AppConstants
          .tauxRemboursement1Fois; // 5% par défaut pour durées invalides
    }
    if (dureeMois == AppConstants.dureeTaux1) {
      return AppConstants.tauxRemboursement1Fois; // 5% pour 1 mois
    } else if (dureeMois <= AppConstants.dureeTaux2a4) {
      return AppConstants.tauxDuree2a4; // 10% pour 2-4 mois
    } else if (dureeMois <= AppConstants.dureeTaux5a8) {
      return AppConstants.tauxDuree5a8; // 15% pour 5-8 mois
    } else {
      return AppConstants.tauxDuree9Plus; // 20% pour 9+ mois
    }
  }

  /// VRAIE RÈGLE MÉTIER : Calcule le taux selon la durée uniquement
  /// Remplace calculateTauxEffectif pour plus de clarté
  static double calculateTauxEffectif(double montant, int dureeMois) {
    // CORRECTION : Utiliser la bonne formule basée sur la durée uniquement
    return calculateTauxSelonDuree(dureeMois);
  }

  /// Applique le multiplicateur de risque basé sur le niveau de confiance client
  /// - Faible risque (4-5/5) : taux divisé par 2
  /// - Risque normal (2-3/5) : taux normal
  /// - Gros risque (1/5) : taux doublé
  /// - Non évalué : taux normal
  static double applyRiskMultiplier(double tauxBase, double? niveauConfiance) {
    if (niveauConfiance == null) {
      return tauxBase; // Non évalué = taux normal
    }

    if (niveauConfiance >= 4.0) {
      return tauxBase / 2; // Faible risque
    } else if (niveauConfiance >= 2.0) {
      return tauxBase; // Risque normal
    } else {
      return tauxBase * 2; // Gros risque
    }
  }

  /// Calcule le taux final avec prise en compte du niveau de confiance
  static double calculateTauxWithRisk(
    double montant,
    int dureeMois,
    double? niveauConfiance,
  ) {
    final tauxBase = calculateTauxEffectif(montant, dureeMois);
    return applyRiskMultiplier(tauxBase, niveauConfiance);
  }

  /// Calcule la mensualité avec TAUX SIMPLE (intérêts fixes)
  /// mensualité = (capital + intérêts_totaux) / durée_mois
  /// intérêts_totaux = capital × (taux_annuel / 100)
  static double calculateMensualite(
    double capital,
    double tauxAnnuel,
    int dureeMois,
  ) {
    if (tauxAnnuel == 0) {
      return capital / dureeMois;
    }

    // TAUX SIMPLE : intérêts fixes calculés sur le capital initial
    final interetsTotaux = capital * (tauxAnnuel / 100);
    final montantTotal = capital + interetsTotaux;
    final mensualite = montantTotal / dureeMois;

    return double.parse(mensualite.toStringAsFixed(2));
  }

  /// Calcule les intérêts totaux avec TAUX SIMPLE
  static double calculateInteretsTotaux(
    double capital,
    double tauxAnnuel,
    int dureeMois,
  ) {
    if (tauxAnnuel == 0) return 0.0;

    // TAUX SIMPLE : intérêts = capital × (taux / 100)
    final interets = capital * (tauxAnnuel / 100);

    return double.parse(interets.toStringAsFixed(2));
  }

  /// Calcule le montant total à rembourser (capital + intérêts)
  static double calculateMontantTotalARembourser(
    double capital,
    double tauxAnnuel,
    int dureeMois,
  ) {
    if (tauxAnnuel == 0) return capital;

    // TAUX SIMPLE : montant total = capital + intérêts
    final interets = capital * (tauxAnnuel / 100);
    final montantTotal = capital + interets;

    return double.parse(montantTotal.toStringAsFixed(2));
  }

  /// Calcule le coût total du prêt
  static double calculateCoutTotal(
    double mensualite,
    int dureeMois,
    double capital,
  ) {
    // CORRECTION : Utiliser le calcul exact des intérêts au lieu du calcul par mensualité
    // qui est faussé par l'arrondi
    // Cette fonction devrait calculer le coût des intérêts uniquement
    return (mensualite * dureeMois) - capital;
  }

  /// Calcule les intérêts totaux de façon exacte (sans arrondi intermédiaire)
  static double calculateInteretsTotauxExacts(
    double capital,
    double tauxAnnuel,
  ) {
    return capital * (tauxAnnuel / 100);
  }

  /// Génère l'échéancier complet du prêt avec TAUX SIMPLE
  /// RÈGLE : Mensualité constante = (Capital + Intérêts totaux) / Durée
  /// Exemple : 1000€ sur 12 mois à 20% → 1200€ total → 100€/mois
  static List<ScheduleItemModel> generateSchedule({
    required String loanId,
    required double capital,
    required double tauxAnnuel,
    required int dureeMois,
    required double mensualite,
    required DateTime datePremierePaiement,
  }) {
    final List<ScheduleItemModel> schedule = [];

    // TAUX SIMPLE : Intérêts totaux calculés sur le capital initial
    final interetsTotaux = capital * (tauxAnnuel / 100);
    final montantTotal = capital + interetsTotaux;

    // Mensualité constante (on recalcule pour éviter les problèmes d'arrondi)
    final mensualiteConstante = montantTotal / dureeMois;

    // Répartition proportionnelle des intérêts et du principal
    final interetMensuel = interetsTotaux / dureeMois;
    final principalMensuel = capital / dureeMois;

    // Gérer les arrondis : accumuler les erreurs pour la dernière mensualité
    double totalPrincipalAccumule = 0;
    double totalInteretAccumule = 0;

    for (int i = 1; i <= dureeMois; i++) {
      final dueDate = DateTime(
        datePremierePaiement.year,
        datePremierePaiement.month + i - 1,
        datePremierePaiement.day,
      );

      double principal;
      double interet;
      double total;

      if (i < dureeMois) {
        // Pour les mensualités 1 à n-1 : utiliser la répartition proportionnelle
        principal = double.parse(principalMensuel.toStringAsFixed(2));
        interet = double.parse(interetMensuel.toStringAsFixed(2));
        total = double.parse(mensualiteConstante.toStringAsFixed(2));

        totalPrincipalAccumule += principal;
        totalInteretAccumule += interet;
      } else {
        // Pour la dernière mensualité : ajuster pour que le total soit exact
        principal = double.parse(
          (capital - totalPrincipalAccumule).toStringAsFixed(2),
        );
        interet = double.parse(
          (interetsTotaux - totalInteretAccumule).toStringAsFixed(2),
        );
        total = principal + interet;
      }

      final scheduleItem = ScheduleItemModel(
        id: '${loanId}_$i',
        loanId: loanId,
        numero: i,
        dueDate: dueDate,
        principal: principal,
        interet: interet,
        total: total,
        createdAt: DateTime.now(),
      );

      schedule.add(scheduleItem);
    }

    return schedule;
  }

  /// Calcule le solde restant d'un prêt selon les paiements effectués
  static double calculateSoldeRestant(List<ScheduleItemModel> schedule) {
    double soldeRestant = 0;

    for (final item in schedule) {
      if (!item.isPaid) {
        soldeRestant += item.principal;
      }
    }

    return soldeRestant;
  }

  /// Calcule le prochain paiement dû
  static ScheduleItemModel? getProchainPaiement(
    List<ScheduleItemModel> schedule,
  ) {
    final unpaidItems = schedule.where((item) => !item.isPaid).toList();
    if (unpaidItems.isEmpty) return null;

    unpaidItems.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaidItems.first;
  }

  /// Vérifie si un prêt est en retard
  static bool isLoanOverdue(List<ScheduleItemModel> schedule) {
    final now = DateTime.now();
    return schedule.any((item) => !item.isPaid && item.dueDate.isBefore(now));
  }

  /// Calcule le nombre total de jours de retard
  static int getTotalDaysOverdue(List<ScheduleItemModel> schedule) {
    final now = DateTime.now();
    int totalDays = 0;

    for (final item in schedule) {
      if (!item.isPaid && item.dueDate.isBefore(now)) {
        totalDays += now.difference(item.dueDate).inDays;
      }
    }

    return totalDays;
  }

  /// Calcule la date de premier remboursement selon les règles :
  /// - Si emprunt entre le 1er et le 10 du mois M → Remboursement le 5 du mois M+1
  /// - Si emprunt entre le 11 et le 31 du mois M → Remboursement le dernier jour du mois M+1
  static DateTime calculateDatePremierRemboursement(DateTime dateEmprunt) {
    final jour = dateEmprunt.day;

    if (jour <= AppConstants.jourLimiteDebutMois) {
      // Emprunt entre le 1er et le 10 → Remboursement le 5 du mois suivant
      return DateTime(
        dateEmprunt.year,
        dateEmprunt.month + 1,
        AppConstants.jourRemboursementDebutMois,
      );
    } else {
      // Emprunt entre le 11 et le 31 → Remboursement le dernier jour du mois suivant
      final moisSuivant = dateEmprunt.month + 1;
      final anneeSuivante = moisSuivant > 12
          ? dateEmprunt.year + 1
          : dateEmprunt.year;
      final moisAjuste = moisSuivant > 12 ? 1 : moisSuivant;

      // Dernier jour du mois suivant
      final dernierJour = DateTime(anneeSuivante, moisAjuste + 1, 0).day;
      return DateTime(anneeSuivante, moisAjuste, dernierJour);
    }
  }

  /// Valide que la durée ne dépasse pas le maximum autorisé (12 mois)
  static bool isDureeValide(int dureeMois) {
    return dureeMois >= AppConstants.dureeMin &&
        dureeMois <= AppConstants.dureeMax;
  }
}
