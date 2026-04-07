import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
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
  print('🚀 DEBUT main() - Application Chafin Loans');

  try {
    print('🔧 WidgetsFlutterBinding.ensureInitialized()...');
    WidgetsFlutterBinding.ensureInitialized();
    print('✅ WidgetsFlutterBinding initialisé');

    // Initialisation Firebase
    print('🔥 Initialisation de Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialisé avec succès');

    // Initialisation des notifications (uniquement mobile)
    if (!kIsWeb) {
      print('🔔 Initialisation des notifications...');
      try {
        final success = await SafeNotificationService.initialize();
        if (success) {
          print('✅ Notifications initialisées avec succès');
        } else {
          print('⚠️ Notifications initialisées avec fallback (mode dégradé)');
        }
      } catch (e) {
        print('⚠️ Erreur notifications (non critique): $e');
        // L'app continue sans notifications
      }
    } else {
      print('🌐 Web détecté - notifications ignorées');
    }

    // Affichage de la configuration
    print('⚙️ Affichage configuration...');
    AppEnvironment.printConfiguration();
    print('✅ Configuration affichée');

    // Démarrage de la maintenance automatique des prêts
    print('🔧 Démarrage de la maintenance automatique...');
    LoanMaintenanceService.startAutoMaintenance();
    print('✅ Maintenance automatique démarrée');

    // Rappels + pénalités gérés UNIQUEMENT par Cloud Functions (dailyPaymentReminders)
    print(
      'ℹ️ Rappels d\'échéances gérés par Cloud Functions (pas de doublon client)',
    );

    print('🚀 Lancement de MyApp()...');
    runApp(const MyApp());
    print('✅ runApp() appelé avec succès');
  } catch (e, stackTrace) {
    print('❌ ERREUR FATALE dans main(): $e');
    print('📍 StackTrace: $stackTrace');
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
    print('🏗️ DEBUT MyApp.build()...');

    try {
      print('📦 Création des providers...');
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) {
              print('🔐 Initialisation AuthProvider...');
              final authProvider = AuthProvider();
              print('🔐 AuthProvider créé, lancement init()...');
              // L'initialisation est maintenant asynchrone mais n'est pas bloquante
              authProvider
                  .init()
                  .then((_) {
                    print('🔐 AuthProvider.init() terminé avec succès');
                  })
                  .catchError((e) {
                    print('❌ Erreur AuthProvider.init(): $e');
                  });
              return authProvider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              print('💰 Initialisation LoanProvider...');
              return LoanProvider();
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              print('👑 Initialisation AdminProvider...');
              return AdminProvider();
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              print('👤 Initialisation BorrowerProvider...');
              return BorrowerProvider();
            },
          ),
        ],
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            print('🎨 Construction MaterialApp avec état auth...');

            // Afficher un écran de chargement pendant l'initialisation
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
                builder: (context, child) {
                  print(
                    '🎨 Builder MaterialApp appelé avec child: ${child.runtimeType}',
                  );
                  return child!;
                },
              );
            } catch (e, stackTrace) {
              print('❌ ERREUR dans MaterialApp.router: $e');
              print('📍 StackTrace: $stackTrace');
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
      print('❌ ERREUR FATALE dans MyApp.build(): $e');
      print('📍 StackTrace: $stackTrace');
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
