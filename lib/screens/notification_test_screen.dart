import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_notification_service.dart';
import '../models/notification_model.dart';

/// Écran de test pour les notifications (développement seulement)
class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Veuillez vous connecter pour tester les notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tests Notifications'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tests de Notifications',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Utilisateur: ${currentUser.nom}\\nEmail: ${currentUser.email}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Section notifications push/app
                  const Text(
                    'Notifications dans l\'app',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildTestButton(
                    'Demande de prêt soumise',
                    () => _testLoanRequested(),
                    Colors.blue,
                  ),
                  _buildTestButton(
                    'Prêt approuvé',
                    () => _testLoanApproved(),
                    Colors.green,
                  ),
                  _buildTestButton(
                    'Prêt refusé',
                    () => _testLoanRejected(),
                    Colors.red,
                  ),
                  _buildTestButton(
                    'Prêt remboursé',
                    () => _testLoanCompleted(),
                    Colors.purple,
                  ),

                  const SizedBox(height: 32),

                  // Actions de gestion
                  const Text(
                    'Actions de gestion',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildTestButton(
                    'Marquer toutes comme lues',
                    () => _markAllAsRead(),
                    Colors.grey,
                  ),
                  _buildTestButton(
                    'Notification générale',
                    () => _testGeneralNotification(),
                    Colors.indigo,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTestButton(String title, VoidCallback onPressed, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(title),
      ),
    );
  }

  Future<void> _executeWithLoading(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action réalisée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testLoanRequested() async {
    final currentUser = context.read<AuthProvider>().currentUser!;
    await _executeWithLoading(() async {
      await AppNotificationService.notifyLoanRequested(
        userId: currentUser.id,
        userEmail: currentUser.email,
        userName: currentUser.nom,
        loanId: 'test-loan-001',
        amount: 5000.0,
        duration: 12,
        rate: 3.5,
      );
    });
  }

  Future<void> _testLoanApproved() async {
    final currentUser = context.read<AuthProvider>().currentUser!;
    await _executeWithLoading(() async {
      await AppNotificationService.notifyLoanApproved(
        userId: currentUser.id,
        userEmail: currentUser.email,
        userName: currentUser.nom,
        loanId: 'test-loan-002',
        amount: 5000.0,
        duration: 12,
        rate: 3.5,
        firstPaymentDate: '15/11/2025',
      );
    });
  }

  Future<void> _testLoanRejected() async {
    final currentUser = context.read<AuthProvider>().currentUser!;
    await _executeWithLoading(() async {
      await AppNotificationService.notifyLoanRejected(
        userId: currentUser.id,
        userEmail: currentUser.email,
        userName: currentUser.nom,
        loanId: 'test-loan-003',
        reason: 'Revenus insuffisants pour le montant demandé',
      );
    });
  }

  Future<void> _testLoanCompleted() async {
    final currentUser = context.read<AuthProvider>().currentUser!;
    await _executeWithLoading(() async {
      await AppNotificationService.notifyLoanCompleted(
        userId: currentUser.id,
        userEmail: currentUser.email,
        userName: currentUser.nom,
        loanId: 'test-loan-006',
        totalAmount: 5425.50,
        completionDate: '29/09/2025',
        duration: 12,
      );
    });
  }

  Future<void> _markAllAsRead() async {
    final currentUser = context.read<AuthProvider>().currentUser!;
    await _executeWithLoading(() async {
      await AppNotificationService.markAllNotificationsAsRead(currentUser.id);
    });
  }

  Future<void> _testGeneralNotification() async {
    final currentUser = context.read<AuthProvider>().currentUser!;
    await _executeWithLoading(() async {
      await AppNotificationService.createNotification(
        userId: currentUser.id,
        title: 'Notification générale',
        body:
            'Ceci est une notification de test générale pour valider le système',
        type: NotificationType.general,
        data: {
          'testId': 'general-001',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    });
  }
}
