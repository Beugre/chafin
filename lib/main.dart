import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/borrower_provider.dart';
import 'utils/app_router.dart';
import 'firebase_options.dart';
import 'config/app_environment.dart';
import 'config/app_theme.dart';
import 'services/safe_notification_service.dart';
import 'services/loan_maintenance_service.dart';

void main() async {
  if (kDebugMode) debugPrint('🚀 DEBUT main() - Application Chafin Loans');

  try {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR', null);

    // Initialisation Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) debugPrint('✅ Firebase initialisé avec succès');

    // Activer la persistence Firestore (cache hors-ligne)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialisation des notifications (uniquement mobile)
    if (!kIsWeb) {
      try {
        await SafeNotificationService.initialize();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Erreur notifications (non critique): $e');
      }
    }

    // Configuration et maintenance
    AppEnvironment.printConfiguration();
    LoanMaintenanceService.startAutoMaintenance();

    runApp(const MyApp());
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('❌ ERREUR FATALE dans main(): $e');
      debugPrint('📍 StackTrace: $stackTrace');
    }
    runApp(ErrorApp(error: 'Erreur main(): $e\n\nStackTrace:\n$stackTrace'));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erreur d\'initialisation'),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) {
              final authProvider = AuthProvider();
              authProvider
                  .init()
                  .then((_) {
                    if (kDebugMode) debugPrint('🔐 AuthProvider.init() terminé');
                  })
                  .catchError((e) {
                    if (kDebugMode) debugPrint('❌ Erreur AuthProvider.init(): $e');
                  });
              return authProvider;
            },
          ),
          ChangeNotifierProvider(create: (_) => LoanProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
          ChangeNotifierProvider(create: (_) => BorrowerProvider()),
        ],
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            // Écran de chargement pendant l'initialisation
            if (authProvider.isInitializing) {
              return MaterialApp(
                title: 'Chafin Loans',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: Scaffold(
                  backgroundColor: Theme.of(context).primaryColor,
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Chafin Loans',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Initialisation...',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Une fois initialisé, afficher l'app normale
            try {
              return MaterialApp.router(
                title: 'Chafin Loans',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                routerConfig: AppRouter.router,
              );
            } catch (e, stackTrace) {
              if (kDebugMode) debugPrint('❌ ERREUR MaterialApp.router: $e');
              return MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text('Erreur MaterialApp'),
                        const SizedBox(height: 8),
                        Text('$e', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('❌ ERREUR FATALE MyApp.build(): $e');
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Erreur MyApp'),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }
  }
}
