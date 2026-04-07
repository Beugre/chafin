import 'package:flutter_test/flutter_test.dart';
import 'package:chafin_loans/services/loan_calculation_service.dart';

void main() {
  group('LoanCalculationService', () {
    group('calculateTauxSelonDuree - Vraies règles métier selon durée', () {
      test('1 mois (remboursement en une fois) → 5%', () {
        expect(LoanCalculationService.calculateTauxSelonDuree(1), 5.0);
      });

      test('2 à 4 mensualités → 10%', () {
        expect(LoanCalculationService.calculateTauxSelonDuree(2), 10.0);
        expect(LoanCalculationService.calculateTauxSelonDuree(3), 10.0);
        expect(LoanCalculationService.calculateTauxSelonDuree(4), 10.0);
      });

      test('5 à 8 mensualités → 15%', () {
        expect(LoanCalculationService.calculateTauxSelonDuree(5), 15.0);
        expect(LoanCalculationService.calculateTauxSelonDuree(6), 15.0);
        expect(LoanCalculationService.calculateTauxSelonDuree(7), 15.0);
        expect(LoanCalculationService.calculateTauxSelonDuree(8), 15.0);
      });

      test('9 mensualités et plus → 20%', () {
        expect(LoanCalculationService.calculateTauxSelonDuree(9), 20.0);
        expect(LoanCalculationService.calculateTauxSelonDuree(10), 20.0);
        expect(LoanCalculationService.calculateTauxSelonDuree(12), 20.0);
      });
    });

    group('calculateTauxEffectif - Vraies règles métier selon durée', () {
      test('1 mois (remboursement en une fois) → 5%', () {
        final taux = LoanCalculationService.calculateTauxEffectif(100, 1);
        expect(taux, 5.0);
      });

      test('2 à 4 mensualités → 10% (ex: 3 mois)', () {
        final taux = LoanCalculationService.calculateTauxEffectif(100, 3);
        expect(taux, 10.0);
      });

      test('2 à 4 mensualités → 10% (ex: 4 mois)', () {
        final taux = LoanCalculationService.calculateTauxEffectif(500, 4);
        expect(taux, 10.0);
      });

      test('5 à 8 mensualités → 15% (ex: 6 mois)', () {
        final taux = LoanCalculationService.calculateTauxEffectif(1000, 6);
        expect(taux, 15.0);
      });

      test('5 à 8 mensualités → 15% (ex: 8 mois)', () {
        final taux = LoanCalculationService.calculateTauxEffectif(2000, 8);
        expect(taux, 15.0);
      });

      test('9+ mensualités → 20% (ex: 9 mois)', () {
        final taux = LoanCalculationService.calculateTauxEffectif(5000, 9);
        expect(taux, 20.0);
      });

      test('9+ mensualités → 20% (ex: 12 mois - cas de votre exemple)', () {
        final taux = LoanCalculationService.calculateTauxEffectif(100, 12);
        expect(taux, 20.0);
      });
    });

    group('calculateMensualite', () {
      test('doit calculer correctement les mensualités avec TAUX SIMPLE', () {
        // Test avec un capital de 1000€, taux 10%, durée 12 mois
        // Taux simple : 1000€ + (1000€ × 10%) = 1100€ total
        // Mensualité : 1100€ ÷ 12 = 91,67€
        final mensualite = LoanCalculationService.calculateMensualite(
          1000,
          10,
          12,
        );

        // Vérifie que la mensualité correspond au calcul taux simple
        expect(mensualite, 91.67);

        // Vérifie que le total des mensualités = capital + intérêts
        final totalPaye = mensualite * 12;
        expect(totalPaye, 1100.04); // 1000€ + 100€ d'intérêts (avec arrondi)
      });

      test('doit gérer le cas taux = 0', () {
        final mensualite = LoanCalculationService.calculateMensualite(
          1200,
          0,
          12,
        );
        expect(mensualite, 100.0); // 1200 / 12
      });
    });

    group('generateSchedule', () {
      test('doit générer le bon nombre d\'échéances', () {
        final schedule = LoanCalculationService.generateSchedule(
          loanId: 'test-loan',
          capital: 1000,
          tauxAnnuel: 10,
          dureeMois: 12,
          mensualite: 87.92, // Valeur approximative
          datePremierePaiement: DateTime(2024, 1, 15),
        );

        expect(schedule.length, 12);

        // Vérifie que les numéros sont corrects
        for (int i = 0; i < schedule.length; i++) {
          expect(schedule[i].numero, i + 1);
        }
      });

      test(
        'doit calculer correctement les intérêts et le principal avec TAUX SIMPLE',
        () {
          final schedule = LoanCalculationService.generateSchedule(
            loanId: 'test-loan',
            capital: 1000,
            tauxAnnuel: 20, // 20% selon nos règles (12 mois)
            dureeMois: 12,
            mensualite: 100.0, // (1000 + 200) / 12
            datePremierePaiement: DateTime(2024, 1, 15),
          );

          // TAUX SIMPLE : intérêts constants chaque mois
          expect(schedule.first.interet, equals(schedule.last.interet));
          expect(schedule.first.principal, equals(schedule.last.principal));

          // Vérifications des montants
          expect(schedule.first.interet, equals(16.67)); // 200 / 12
          expect(schedule.first.principal, equals(83.33)); // 1000 / 12

          // La somme des principaux doit égaler le capital
          final totalPrincipal = schedule.fold<double>(
            0,
            (sum, item) => sum + item.principal,
          );
          expect(totalPrincipal, closeTo(1000, 1.0)); // Tolérance d'arrondi
        },
      );
    });
  });
}
