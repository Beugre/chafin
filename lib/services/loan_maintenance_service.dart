import 'dart:async';
import 'package:flutter/material.dart';
import '../services/loan_service.dart';

/// Service de maintenance automatique pour les prêts
class LoanMaintenanceService {
  static final LoanService _loanService = LoanService();
  static Timer? _maintenanceTimer;

  /// Démarre la maintenance automatique (toutes les heures)
  static void startAutoMaintenance() {
    // Annuler le timer existant s'il y en a un
    stopAutoMaintenance();

    // Démarrer un nouveau timer qui se déclenche toutes les heures
    _maintenanceTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _performMaintenance(),
    );

    // Exécuter une maintenance immédiatement
    _performMaintenance();

    debugPrint('🔧 Maintenance automatique des prêts démarrée');
  }

  /// Arrête la maintenance automatique
  static void stopAutoMaintenance() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = null;
    debugPrint('🔧 Maintenance automatique des prêts arrêtée');
  }

  /// Exécute la maintenance (clôture des prêts soldés)
  static Future<void> _performMaintenance() async {
    try {
      debugPrint('🔧 Début de la maintenance des prêts...');

      await _loanService.autoCloseCompletedLoans();

      debugPrint('✅ Maintenance des prêts terminée avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de la maintenance des prêts: $e');
    }
  }

  /// Force une maintenance manuelle
  static Future<void> runMaintenanceNow() async {
    await _performMaintenance();
  }
}
