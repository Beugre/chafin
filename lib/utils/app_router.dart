import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/borrower/main_app_screen.dart';
import '../screens/borrower/loan_request_screen.dart';
import '../screens/borrower/loan_details_screen.dart';
import '../screens/admin/modern_admin_dashboard_screen.dart';
import '../screens/admin/modern_loan_management_screen.dart';
import '../screens/admin/create_admin_screen.dart';
import '../screens/admin/email_test_screen.dart';
import '../screens/admin/loan_notifications_test_screen.dart';
import '../screens/admin/payment_reminder_screen.dart';
import '../screens/admin/reminder_test_screen.dart';
import '../screens/admin/risk_management_screen.dart';
import '../screens/admin/edit_schedule_dates_screen.dart';
import '../screens/admin/loan_review_screen.dart';
import '../screens/admin/admin_chat_screen.dart';
import '../screens/notification_test_screen.dart';
import '../screens/payment_schedule_list_screen.dart';
import '../screens/borrower/edit_profile_screen.dart';
import '../providers/auth_provider.dart';
import '../models/loan_model.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isInitializing = authProvider.isInitializing;
      final isLoggedIn = authProvider.isLoggedIn;
      final isAdmin = authProvider.isAdmin;

      // Si encore en cours d'initialisation, pas de redirection
      if (isInitializing) {
        return null;
      }

      final authRoutes = [
        '/login',
        '/register',
        '/forgot-password',
        '/notification-test',
      ];
      final adminRoutes = [
        '/admin',
        '/admin/loans',
        '/admin/loan-review',
        '/admin/create-admin',
        '/admin/email-test',
        '/admin/payment-reminders',
      ];
      final borrowerRoutes = [
        '/dashboard',
        '/my-loans',
        '/profile',
        '/profile/edit',
        '/borrower/loan',
        '/loan-request',
        '/loan/create',
        '/notifications',
        '/payment-schedule',
        '/chat',
      ];

      // Routes partagées (accessibles par admin et emprunteur)
      final sharedRoutes = ['/loan-details'];

      // Si pas connecté et pas sur une route d'auth, rediriger vers login
      if (!isLoggedIn && !authRoutes.contains(state.matchedLocation)) {
        return '/login';
      }

      // Si connecté et sur une route d'auth, rediriger selon le rôle
      if (isLoggedIn && authRoutes.contains(state.matchedLocation)) {
        return isAdmin ? '/admin' : '/dashboard';
      }

      // Si non-admin essaie d'accéder aux routes admin
      if (!isAdmin &&
          adminRoutes.any((route) => state.matchedLocation.startsWith(route))) {
        return '/dashboard';
      }

      // Si admin essaie d'accéder aux routes emprunteur (sauf routes partagées)
      if (isAdmin &&
          borrowerRoutes.any(
            (route) => state.matchedLocation.startsWith(route),
          ) &&
          !sharedRoutes.any(
            (route) => state.matchedLocation.startsWith(route),
          )) {
        return '/admin';
      }

      return null;
    },
    routes: [
      // Routes d'authentification
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Routes emprunteur avec nouvelle interface moderne
      GoRoute(
        path: '/dashboard',
        name: 'borrower-dashboard',
        builder: (context, state) =>
            const MainAppScreen(initialLocation: '/dashboard'),
      ),
      GoRoute(
        path: '/my-loans',
        name: 'my-loans',
        builder: (context, state) =>
            const MainAppScreen(initialLocation: '/my-loans'),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) =>
            const MainAppScreen(initialLocation: '/profile'),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/borrower/loan/:loanId',
        name: 'borrower-loan-detail',
        builder: (context, state) {
          final loanId = state.pathParameters['loanId']!;
          return LoanDetailsScreen(loanId: loanId);
        },
      ),
      GoRoute(
        path: '/loan/create',
        name: 'loan-create',
        builder: (context, state) => const LoanRequestScreen(),
      ),
      GoRoute(
        path: '/loan-request',
        name: 'loan-request',
        builder: (context, state) => const LoanRequestScreen(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) =>
            const MainAppScreen(initialLocation: '/chat'),
      ),
      GoRoute(
        path: '/loan-details/:loanId',
        name: 'loan-details',
        builder: (context, state) {
          final loanId = state.pathParameters['loanId']!;
          return LoanDetailsScreen(loanId: loanId);
        },
      ),

      // Routes admin
      GoRoute(
        path: '/admin',
        name: 'admin-dashboard',
        builder: (context, state) => const ModernAdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/loans',
        name: 'loan-management',
        builder: (context, state) => const ModernLoanManagementScreen(),
      ),
      GoRoute(
        path: '/admin/loan-review/:loanId',
        name: 'loan-review',
        builder: (context, state) {
          final loanId = state.pathParameters['loanId']!;
          return LoanReviewScreen(loanId: loanId);
        },
      ),

      GoRoute(
        path: '/admin/create-admin',
        name: 'create-admin',
        builder: (context, state) => const CreateAdminScreen(),
      ),
      GoRoute(
        path: '/admin/email-test',
        name: 'admin-email-test',
        builder: (context, state) => const EmailTestScreen(),
      ),
      GoRoute(
        path: '/admin/loan-notifications-test',
        name: 'admin-loan-notifications-test',
        builder: (context, state) => const LoanNotificationsTestScreen(),
      ),
      GoRoute(
        path: '/admin/payment-reminders',
        name: 'admin-payment-reminders',
        builder: (context, state) => const PaymentReminderScreen(),
      ),
      GoRoute(
        path: '/admin/reminder-test',
        name: 'admin-reminder-test',
        builder: (context, state) => const ReminderTestScreen(),
      ),
      GoRoute(
        path: '/admin/risk-management',
        name: 'admin-risk-management',
        builder: (context, state) => const RiskManagementScreen(),
      ),
      GoRoute(
        path: '/admin/edit-schedule-dates/:loanId',
        name: 'admin-edit-schedule-dates',
        builder: (context, state) {
          final loan = state.extra as LoanModel;
          return EditScheduleDatesScreen(loan: loan);
        },
      ),
      GoRoute(
        path: '/admin/chat',
        name: 'admin-chat',
        builder: (context, state) => const AdminChatScreen(),
      ),

      // Route de setup admin (développement uniquement)
      // Route des échéances
      GoRoute(
        path: '/payment-schedule',
        name: 'payment-schedule',
        builder: (context, state) => const PaymentScheduleListScreen(),
      ),

      // Route des notifications
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) =>
            const MainAppScreen(initialLocation: '/notifications'),
      ),

      // Route de test des notifications (développement)
      GoRoute(
        path: '/notification-test',
        name: 'notification-test',
        builder: (context, state) => const NotificationTestScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page non trouvée',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'La page "${state.matchedLocation}" n\'existe pas.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
}
