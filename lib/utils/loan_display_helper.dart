import '../models/loan_model.dart';

/// Classe utilitaire pour calculer et afficher les bonnes valeurs des prêts
/// en utilisant la méthode de calcul simple (intérêts non composés)
class LoanDisplayHelper {
  /// Calcule les bonnes valeurs d'affichage pour un prêt
  /// Utilise les valeurs stockées en base quand disponibles
  static LoanDisplayValues calculateDisplayValues(LoanModel loan) {
    final montant = loan.montant;
    final dureeMois = loan.dureeMois;
    final taux = loan.tauxAnnuel;

    // Utiliser les valeurs de la base si disponibles
    final mensualite = loan.mensualite;
    final interetsTotaux =
        loan.coutTotalEstime; // coutTotalEstime = coût du crédit = intérêts
    final coutTotal = montant + interetsTotaux; // capital + intérêts

    return LoanDisplayValues(
      montantDemande: montant,
      tauxInteret: taux,
      interetsTotaux: interetsTotaux,
      coutTotal: coutTotal,
      mensualite: mensualite,
      dureeMois: dureeMois,
    );
  }
}

/// Classe pour encapsuler les valeurs d'affichage calculées
class LoanDisplayValues {
  final double montantDemande;
  final double tauxInteret;
  final double interetsTotaux;
  final double coutTotal;
  final double mensualite;
  final int dureeMois;

  const LoanDisplayValues({
    required this.montantDemande,
    required this.tauxInteret,
    required this.interetsTotaux,
    required this.coutTotal,
    required this.mensualite,
    required this.dureeMois,
  });

  /// Formate le montant demandé
  String get montantDemandeFormatted => '${montantDemande.toStringAsFixed(0)}€';

  /// Formate le taux d'intérêt
  String get tauxInteretFormatted => '${tauxInteret.toStringAsFixed(2)}%';

  /// Formate les intérêts totaux
  String get interetsTotauxFormatted => '${interetsTotaux.toStringAsFixed(0)}€';

  /// Formate le coût total
  String get coutTotalFormatted => '${coutTotal.toStringAsFixed(0)}€';

  /// Formate la mensualité
  String get mensualiteFormatted => '${mensualite.toStringAsFixed(0)}€';

  /// Formate la durée
  String get dureeMoisFormatted => '$dureeMois mois';
}
