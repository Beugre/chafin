import 'package:flutter_test/flutter_test.dart';
import 'package:chafin_loans/utils/constants.dart';

void main() {
  testWidgets('Constants are defined correctly', (WidgetTester tester) async {
    // Test que les constantes de base sont définies
    expect(AppConstants.montantMin, 10.0);
    expect(AppConstants.seuil1, 2000.0);
    expect(AppConstants.seuil2, 10000.0);

    // Test des taux de base
    expect(AppConstants.tauxBase1, 10.0);
    expect(AppConstants.tauxBase2, 5.0);
    expect(AppConstants.tauxBase3, 2.5);

    // Test des coefficients
    expect(AppConstants.coeff1, 1.0);
    expect(AppConstants.coeff2, 1.5);
    expect(AppConstants.coeff3, 2.0);
  });
}
