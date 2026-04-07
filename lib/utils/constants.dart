/// Constantes de l'application pour les calculs de prêts
class AppConstants {
  // Montants seuils
  static const double montantMin = 10.0;
  static const double seuil1 = 2000.0;
  static const double seuil2 = 10000.0;

  // Taux d'intérêt selon la durée (en pourcentage) - NOUVELLE FORMULE
  static const double tauxRemboursement1Fois =
      5.0; // Remboursement en 1 fois => 5%
  static const double tauxDuree2a4 = 10.0; // 2 à 4 mensualités => 10%
  static const double tauxDuree5a8 = 15.0; // 5 à 8 mensualités => 15%
  static const double tauxDuree9Plus = 20.0; // 9 mensualités et + => 20%

  // Durées seuils (en mois) - MISE À JOUR
  static const int dureeMin = 1;
  static const int dureeMax = 12; // Maximum 12 mois
  static const int dureeTaux1 = 1; // 1 mois (remboursement en une fois)
  static const int dureeTaux2a4 = 4; // 2 à 4 mois
  static const int dureeTaux5a8 = 8; // 5 à 8 mois
  // 9+ mois utilisent tauxDuree9Plus

  // Règles de dates de remboursement
  static const int jourLimiteDebutMois = 10; // Si emprunt entre 1-10
  static const int jourRemboursementDebutMois =
      5; // Remboursement le 5 du mois suivant
  // Si emprunt entre 11-31, remboursement le dernier jour du mois suivant

  // ANCIENS PARAMÈTRES (conservés pour compatibilité pendant migration)
  static const double tauxBase1 = 10.0; // OBSOLÈTE
  static const double tauxBase2 = 5.0; // OBSOLÈTE
  static const double tauxBase3 = 2.5; // OBSOLÈTE
  static const int dureeCoeff1 = 12; // OBSOLÈTE
  static const int dureeCoeff2 = 24; // OBSOLÈTE
  static const double coeff1 = 1.0; // OBSOLÈTE
  static const double coeff2 = 1.5; // OBSOLÈTE
  static const double coeff3 = 2.0; // OBSOLÈTE

  // Statuts de notification
  static const int rappelJ7 = 7; // Rappel à J-7
  static const int rappelJ1 = 1; // Rappel à J-1
  static const int retardJ3 = 3; // Retard à J+3
  static const int retardJ10 = 10; // Retard à J+10

  // Formats et devises
  static const String devise = 'EUR';
  static const String locale = 'fr_FR';
  static const String timezone = 'Europe/Paris';

  // Pénalités de retard
  static const double tauxPenaliteRetard = 5.0; // 5% par échéance en retard
  static const int seuilJoursRisque = 60; // 2 mois de retard => gros risque

  // Paramètres par défaut
  static const int paginationLimit = 20;
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
}
