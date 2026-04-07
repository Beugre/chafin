/// Configuration d'environnement pour l'application Chafin
class AppEnvironment {
  static const String _environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  /// Environnement actuel (dev, prod)
  static String get environment => _environment;

  /// Indique si on est en développement
  static bool get isDevelopment => _environment == 'dev';

  /// Indique si on est en production
  static bool get isProduction => _environment == 'prod';

  /// Configuration Firebase selon l'environnement
  static String get firebaseProjectId {
    switch (_environment) {
      case 'prod':
        return 'chafin-23cad';
      case 'dev':
      default:
        return 'chafin-23cad'; // Même projet pour l'instant
    }
  }

  /// Configuration du domaine API
  static String get apiDomain {
    switch (_environment) {
      case 'prod':
        return 'https://chafin-23cad.web.app';
      case 'dev':
      default:
        return 'http://localhost:5000';
    }
  }

  /// Configuration des logs
  static bool get enableLogs => isDevelopment;

  /// Configuration du debug
  static bool get enableDebugFeatures => isDevelopment;

  /// URL de support client
  static String get supportUrl {
    switch (_environment) {
      case 'prod':
        return 'https://chafin-support.com';
      case 'dev':
      default:
        return 'mailto:dev@chafin.com';
    }
  }

  /// Limites selon l'environnement
  static AppLimits get limits {
    switch (_environment) {
      case 'prod':
        return const AppLimits(
          maxLoanAmount: 50000.0,
          minLoanAmount: 10.0,
          maxLoanDuration: 60,
          minLoanDuration: 1,
          maxFileSize: 10 * 1024 * 1024, // 10 MB
        );
      case 'dev':
      default:
        return const AppLimits(
          maxLoanAmount: 100000.0,
          minLoanAmount: 1.0,
          maxLoanDuration: 120,
          minLoanDuration: 1,
          maxFileSize: 50 * 1024 * 1024, // 50 MB pour les tests
        );
    }
  }

  /// Afficher la configuration actuelle
  static void printConfiguration() {
    if (!enableLogs) return;

    print('=== Configuration Chafin ===');
    print('Environnement: $_environment');
    print('Firebase Project: $firebaseProjectId');
    print('API Domain: $apiDomain');
    print('Debug Features: $enableDebugFeatures');
    print('Support URL: $supportUrl');
    print('Limits: $limits');
    print('============================');
  }
}

/// Limites de l'application selon l'environnement
class AppLimits {
  final double maxLoanAmount;
  final double minLoanAmount;
  final int maxLoanDuration;
  final int minLoanDuration;
  final int maxFileSize;

  const AppLimits({
    required this.maxLoanAmount,
    required this.minLoanAmount,
    required this.maxLoanDuration,
    required this.minLoanDuration,
    required this.maxFileSize,
  });

  @override
  String toString() {
    return 'AppLimits(loan: $minLoanAmount-$maxLoanAmount€, '
        'duration: $minLoanDuration-$maxLoanDuration mois, '
        'file: ${(maxFileSize / (1024 * 1024)).toStringAsFixed(1)} MB)';
  }
}
