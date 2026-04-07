import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/loan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/loan_model.dart';
import '../../models/payment_schedule_model.dart';

import '../../services/payment_schedule_service.dart';
import '../../services/admin_service.dart';
import '../../widgets/early_repayment_dialog.dart';
import '../../services/early_repayment_service.dart';
import 'payment_schedule_screen.dart';

class LoanDetailsScreen extends StatefulWidget {
  final String loanId;

  const LoanDetailsScreen({super.key, required this.loanId});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LoanModel? loan;
  PaymentSchedule? paymentSchedule;
  bool isLoading = true;
  double? tauxRecalcule;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLoanDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLoanDetails() async {
    print('🔄 _loadLoanDetails appelé pour prêt: ${widget.loanId}');
    setState(() => isLoading = true);

    try {
      final loanProvider = Provider.of<LoanProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Si admin, utiliser AdminProvider, sinon LoanProvider
      print('=== ADMIN DEBUG ===');
      print('isAdmin: ${authProvider.isAdmin}');
      print('loanId recherché: ${widget.loanId}');

      if (authProvider.isAdmin) {
        // Admin : utiliser AdminProvider qui gère les données admin
        final adminProvider = Provider.of<AdminProvider>(
          context,
          listen: false,
        );
        print('AdminProvider allLoans count: ${adminProvider.allLoans.length}');
        if (adminProvider.allLoans.isEmpty) {
          print('Chargement des données admin...');
          await adminProvider.loadAllAdminData();
          print(
            'Après chargement - allLoans count: ${adminProvider.allLoans.length}',
          );
        }
      } else {
        // Emprunteur : charger seulement ses prêts
        if (loanProvider.userLoans.isEmpty &&
            authProvider.currentUser != null) {
          await loanProvider.loadUserLoans(authProvider.currentUser!.id);
        }
      }

      // Trouver le prêt dans la bonne liste selon le rôle
      LoanModel? foundLoan;
      try {
        if (authProvider.isAdmin) {
          // Admin : chercher dans AdminProvider
          final adminProvider = Provider.of<AdminProvider>(
            context,
            listen: false,
          );
          print('Prêts disponibles dans AdminProvider:');
          for (var loan in adminProvider.allLoans) {
            print('- ID: ${loan.id}, Montant: ${loan.montant}€');
          }

          foundLoan = adminProvider.allLoans.firstWhere(
            (loan) => loan.id == widget.loanId,
          );
          print('Prêt trouvé: ${foundLoan.id}');
        } else {
          // Emprunteur : chercher dans ses prêts
          print('Prêts disponibles dans LoanProvider:');
          for (var loan in loanProvider.userLoans) {
            print('- ID: ${loan.id}, Montant: ${loan.montant}€');
          }

          foundLoan = loanProvider.userLoans.firstWhere(
            (loan) => loan.id == widget.loanId,
          );
          print('Prêt trouvé: ${foundLoan.id}');
        }
      } catch (e) {
        print('ERREUR: Prêt non trouvé - $e');
        foundLoan = null;
      }

      setState(() {
        // Utiliser directement les valeurs de la base (elles sont mises à jour après modification du taux)
        loan = foundLoan;
        isLoading = false;
      });

      // Charger l'échéancier depuis Firebase si le prêt est décaissé ou en cours (après setState)
      if (loan != null &&
          (loan!.statut == LoanStatus.enCours ||
              loan!.statut == LoanStatus.decaissementEffectue ||
              loan!.statut == LoanStatus.enRetard ||
              loan!.statut == LoanStatus.approuve ||
              loan!.statut == LoanStatus.solde)) {
        await _loadScheduleFromFirebase(loan!);
        setState(() {}); // Redessiner l'interface avec l'échéancier chargé
      }

      // Synchroniser avec les statuts de paiement réels depuis Firestore (après setState)
      if (paymentSchedule != null) {
        await _syncPaymentStatuses();
        setState(() {}); // Redessiner l'interface avec les nouveaux statuts
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Synchroniser les statuts de paiement depuis Firestore
  /// Recherche par requête loanId + numero (compatible avec tous les formats d'ID)
  Future<void> _syncPaymentStatuses() async {
    if (paymentSchedule == null || loan == null) return;

    try {
      print('🔄 Synchronisation des statuts de paiement...');

      final firestore = FirebaseFirestore.instance;
      final List<PaymentScheduleItem> updatedEcheances = [];

      print(
        '📊 Chargement échéancier - ${paymentSchedule!.echeances.length} échéances générées',
      );

      // Charger toutes les échéances du prêt en une seule requête (plus efficace)
      final allSchedules = await firestore
          .collection('schedules')
          .where('loanId', isEqualTo: loan!.id)
          .get();

      // Créer un index par numéro d'échéance pour un accès rapide
      final Map<int, Map<String, dynamic>> scheduleByNumero = {};
      for (final doc in allSchedules.docs) {
        final data = doc.data();
        final numero = data['numero'] as int?;
        if (numero != null) {
          scheduleByNumero[numero] = data;
        }
      }

      print(
        '📦 ${scheduleByNumero.length} échéances trouvées en base pour le prêt ${loan!.id}',
      );

      // Pour chaque échéance, vérifier si elle est marquée comme payée en base
      for (final echeance in paymentSchedule!.echeances) {
        final data = scheduleByNumero[echeance.numeroEcheance];

        if (data != null) {
          final isPaid = data['isPaid'] as bool? ?? false;
          final montant = data['total'] as double? ?? 0.0;

          print(
            '📄 Échéance ${echeance.numeroEcheance} en base: $montant€ (payée: $isPaid)',
          );

          if (isPaid) {
            print('✅ Échéance ${echeance.numeroEcheance} marquée comme payée');
            updatedEcheances.add(
              echeance.copyWith(statut: PaymentStatus.payee),
            );
          } else {
            updatedEcheances.add(echeance);
          }
        } else {
          print('⚠️ Échéance ${echeance.numeroEcheance} non trouvée en base');
          updatedEcheances.add(echeance);
        }
      }

      // Créer un nouvel échéancier avec les statuts mis à jour
      paymentSchedule = PaymentSchedule(
        loanId: paymentSchedule!.loanId,
        echeances: updatedEcheances,
        createdAt: paymentSchedule!.createdAt,
        updatedAt: DateTime.now(),
      );

      print('✅ Synchronisation terminée');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation: $e');
    }
  }

  /// Confirmer le décaissement d'un prêt approuvé (fonction admin)
  Future<void> _confirmDisbursement() async {
    if (loan == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin) return;

    // Dialog de confirmation avec référence OPTIONNELLE
    final TextEditingController referenceController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payments, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Confirmer le décaissement'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Montant à décaisser: ${loan!.montant.toStringAsFixed(2)} €\n'
              'Emprunteur: ${loan!.nomEmprunteur}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Référence virement (optionnel)',
                hintText: 'Ex: VIR241001-001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note admin (optionnel)',
                hintText: 'Commentaire sur le décaissement...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirmer le décaissement',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Afficher un indicateur de chargement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Text('Confirmation du décaissement en cours...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 8),
          ),
        );
      }

      // Appeler le service d'administration pour confirmer le décaissement
      final adminService = AdminService();

      await adminService.confirmLoanDisbursement(
        loan!.id,
        referenceDecaissement: referenceController.text.trim().isNotEmpty
            ? referenceController.text.trim()
            : null, // Maintenant optionnel, généré automatiquement côté service
        noteAdmin: noteController.text.trim().isNotEmpty
            ? noteController.text.trim()
            : null,
      );

      // Fermer le snackbar de chargement
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Recharger les détails du prêt
      await _loadLoanDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Text('Décaissement confirmé et échéancier généré !'),
              ],
            ),
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Fermer le snackbar de chargement
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.error, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Erreur lors du décaissement: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      // Nettoyer les contrôleurs
      referenceController.dispose();
      noteController.dispose();
    }
  }

  /// Afficher la boîte de dialogue d'annulation du prêt
  Future<void> _showCancelLoanDialog() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Annuler le prêt'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Êtes-vous sûr de vouloir annuler ce prêt ? Cette action est irréversible.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif d\'annulation (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Confirmer l\'annulation',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final loanProvider = Provider.of<LoanProvider>(context, listen: false);

      if (authProvider.currentUser != null && loan != null) {
        final success = await loanProvider.cancelLoan(
          loan!.id,
          authProvider.currentUser!.id,
          reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
          authProvider.isAdmin,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prêt annulé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          // Recharger les données
          setState(() {
            isLoading = true;
          });
          _loadLoanDetails();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loanProvider.errorMessage ?? 'Erreur lors de l\'annulation',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    reasonController.dispose();
  }

  /// Afficher le dialog de simulation de remboursement anticipé (emprunteur)
  Future<void> _showEarlyRepaymentDialog() async {
    if (loan == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.isAdmin;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EarlyRepaymentDialog(
        loan: loan!,
        isSimulationOnly:
            !isAdmin, // Simulation pour les emprunteurs, traitement pour les admins
        onConfirm: isAdmin
            ? (montantAnticipe, nouvelleDuree) async {
                // Callback pour les admins seulement
                final earlyRepaymentService = EarlyRepaymentService();

                try {
                  setState(() => isLoading = true);

                  final success = await earlyRepaymentService
                      .processEarlyRepayment(
                        loanId: loan!.id,
                        montantAnticipe: montantAnticipe,
                        nouvelleDuree: nouvelleDuree,
                        userId: authProvider.currentUser!.id,
                        noteUtilisateur:
                            'Traité par admin: ${authProvider.currentUser!.nom}',
                      );

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Remboursement anticipé traité avec succès !',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Recharger les détails du prêt
                    await _loadLoanDetails();
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Erreur lors du traitement du remboursement anticipé',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => isLoading = false);
                  }
                }
              }
            : null, // Pas de callback pour les emprunteurs
      ),
    );
  }

  /// Marquer une échéance comme payée (fonction admin)
  Future<void> _markPaymentAsPaid(PaymentScheduleItem echeance) async {
    // Fonction debug avec affichage dans l'UI
    void showDebugMessage(String message) {
      print(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (loan == null) {
      showDebugMessage('ERREUR: Aucun prêt chargé');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin) {
      showDebugMessage(
        'ERREUR: Utilisateur non admin (${authProvider.currentUser?.role})',
      );
      return;
    }

    if (authProvider.currentUser == null) {
      showDebugMessage('ERREUR: Aucun utilisateur connecté');
      return;
    }

    showDebugMessage('=== MARK PAYMENT DEBUG ===');
    showDebugMessage('Loan ID: ${loan!.id}');
    showDebugMessage('Échéance: ${echeance.numeroEcheance}');
    showDebugMessage('Montant: ${echeance.montantTotal}');
    showDebugMessage('Admin ID: ${authProvider.currentUser!.id}');
    showDebugMessage('Admin nom: ${authProvider.currentUser!.nom}');
    showDebugMessage(
      'Schedule Item ID: ${loan!.id}_${echeance.numeroEcheance}',
    );

    try {
      // Afficher une boîte de dialogue de confirmation style Revolut
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payment, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Confirmer le paiement'),
            ],
          ),
          content: Text(
            'Marquer l\'échéance ${echeance.numeroEcheance} comme payée ?\n\n'
            'Montant: ${echeance.montantTotal.toStringAsFixed(2)} €\n'
            'Date: ${DateFormat('dd/MM/yyyy').format(echeance.dateEcheance)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirmer',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        print('Paiement annulé par l\'utilisateur');
        return;
      }

      // Afficher un indicateur de chargement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Text('Marquage du paiement en cours...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
      }

      showDebugMessage('Tentative de marquage du paiement...');

      // Marquer le paiement comme reçu
      final loanProvider = Provider.of<LoanProvider>(context, listen: false);
      showDebugMessage('LoanProvider récupéré avec succès');

      final scheduleItemId = '${loan!.id}_${echeance.numeroEcheance}';
      showDebugMessage('Schedule Item ID créé: $scheduleItemId');

      final success = await loanProvider.markPaymentReceived(
        scheduleItemId: scheduleItemId,
        adminId: authProvider.currentUser!.id,
        amount: echeance.montantTotal,
        note: 'Marqué comme payé par admin ${authProvider.currentUser!.nom}',
      );

      showDebugMessage('Résultat marquage: $success');

      // Fermer le snackbar de chargement
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        showDebugMessage('SUCCESS: Paiement marqué avec succès');
        // Recharger les détails du prêt pour actualiser l'affichage
        await _loadLoanDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Paiement marqué comme reçu avec succès'),
                ],
              ),
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        showDebugMessage('ÉCHEC: markPaymentReceived a retourné false');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Échec du marquage - Vérifiez les logs'),
                ],
              ),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      showDebugMessage('ERREUR CRITIQUE lors du marquage: $e');
      print('Stack trace: $stackTrace');

      // Fermer le snackbar de chargement
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.bug_report,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Erreur technique: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  /// Charger l'échéancier directement depuis Firebase
  Future<void> _loadScheduleFromFirebase(LoanModel loan) async {
    try {
      print('🔄 Chargement échéancier depuis Firebase pour prêt: ${loan.id}');

      final firestore = FirebaseFirestore.instance;
      final scheduleQuery = await firestore
          .collection('schedules')
          .where('loanId', isEqualTo: loan.id)
          .orderBy('numero')
          .get();

      if (scheduleQuery.docs.isNotEmpty) {
        print('📊 ${scheduleQuery.docs.length} échéances trouvées en base');

        final List<PaymentScheduleItem> echeances = [];

        for (final doc in scheduleQuery.docs) {
          final data = doc.data();

          // Créer un PaymentScheduleItem à partir des données Firebase
          final montantTotal = data['total'] as double;
          final montantCapital = data['principal'] as double;
          final montantInterets = data['interet'] as double;

          final echeance = PaymentScheduleItem(
            numeroEcheance: data['numero'] as int,
            dateEcheance: (data['dueDate'] as Timestamp).toDate(),
            montantTotal: montantTotal,
            montantCapital: montantCapital,
            montantInterets: montantInterets,
            capitalRestantDu: 0.0, // TODO: calculer le capital restant dû
            statut: (data['isPaid'] as bool? ?? false)
                ? PaymentStatus.payee
                : PaymentStatus.aVenir,
          );

          echeances.add(echeance);
          print(
            '📄 Échéance ${echeance.numeroEcheance}: ${echeance.montantTotal}€ (statut: ${echeance.statut})',
          );
        }

        // Créer l'objet PaymentSchedule avec les échéances chargées
        paymentSchedule = PaymentSchedule(
          loanId: loan.id,
          echeances: echeances,
          createdAt: DateTime.now(),
        );

        print(
          '✅ Échéancier chargé depuis Firebase avec ${echeances.length} échéances',
        );
      } else {
        print('⚠️  Aucune échéance trouvée en base - génération automatique');
        // Générer et sauvegarder l'échéancier automatiquement
        final schedules = await _generateAndSaveSchedule(loan);

        // Créer l'objet PaymentSchedule avec les échéances générées
        if (schedules.isNotEmpty) {
          paymentSchedule = PaymentSchedule(
            loanId: loan.id,
            echeances: schedules,
            createdAt: DateTime.now(),
          );
          print('✅ Échéancier généré avec ${schedules.length} échéances');
        }
      }
    } catch (e) {
      print('❌ Erreur lors du chargement de l\'échéancier: $e');
      // Fallback vers l'ancien système en cas d'erreur
      await _loadScheduleFromOldSystem(loan);
    }
  }

  /// Générer et sauvegarder l'échéancier dans Firebase
  Future<List<PaymentScheduleItem>> _generateAndSaveSchedule(
    LoanModel loan,
  ) async {
    final List<PaymentScheduleItem> echeances = [];

    try {
      print('🔧 Génération automatique de l\'échéancier pour ${loan.id}');

      final firestore = FirebaseFirestore.instance;
      final startDate =
          loan.datePremierRemboursement ??
          DateTime.now().add(const Duration(days: 5));

      // Calculer avec formule TAUX SIMPLE
      final interetsTotal = loan.montant * (loan.tauxAnnuel / 100);
      final montantTotal = loan.montant + interetsTotal;
      final mensualite = montantTotal / loan.dureeMois;

      // Générer et sauvegarder chaque échéance
      for (int i = 0; i < loan.dureeMois; i++) {
        final dueDate = DateTime(
          startDate.year,
          startDate.month + i,
          startDate.day,
        );

        await firestore.collection('schedules').add({
          'loanId': loan.id,
          'numero': i + 1,
          'dueDate': Timestamp.fromDate(dueDate),
          'principal': loan.montant / loan.dureeMois,
          'interet': interetsTotal / loan.dureeMois,
          'total': mensualite,
          'isPaid': false,
          'paidAt': null,
          'paidAmount': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Créer l'objet PaymentScheduleItem
        echeances.add(
          PaymentScheduleItem(
            numeroEcheance: i + 1,
            dateEcheance: dueDate,
            montantTotal: mensualite,
            montantCapital: loan.montant / loan.dureeMois,
            montantInterets: interetsTotal / loan.dureeMois,
            capitalRestantDu: 0.0,
            statut: PaymentStatus.aVenir,
          ),
        );
      }

      print(
        '✅ Échéancier généré et sauvegardé (${loan.dureeMois} mensualités)',
      );
    } catch (e) {
      print('❌ Erreur génération échéancier: $e');
    }

    return echeances;
  }

  /// Fallback : charger l'échéancier avec l'ancien système
  Future<void> _loadScheduleFromOldSystem(LoanModel loan) async {
    try {
      print('🔄 Fallback : génération échéancier avec ancien système');
      paymentSchedule = PaymentScheduleService.generateSchedule(
        loanId: loan.id,
        montantPret: loan.montant,
        dureeMois: loan.dureeMois,
        tauxAnnuel: loan.tauxAnnuel,
        dateDecaissement: loan.disbursedAt ?? loan.approvedAt ?? DateTime.now(),
      );
      print(
        '✅ Échéancier généré avec ${paymentSchedule?.echeances.length ?? 0} échéances',
      );
    } catch (e) {
      print('❌ Erreur fallback : $e');
      paymentSchedule = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadLoanDetails,
        child: CustomScrollView(
          slivers: [
            // Modern SliverAppBar avec gradient Revolut
            SliverAppBar(
              expandedHeight: 100,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: () {
                  // Si on peut revenir en arrière (push), on pop
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    // Fallback : rediriger vers le bon écran selon le rôle
                    if (authProvider.isAdmin) {
                      context.go('/admin/loans');
                    } else {
                      context.go('/my-loans');
                    }
                  }
                },
              ),
              actions: [
                // Bouton de décaissement pour admin si prêt approuvé
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (loan != null &&
                        authProvider.isAdmin &&
                        loan!.statut == LoanStatus.approuve) {
                      return Container(
                        margin: const EdgeInsets.only(
                          right: 16,
                          top: 8,
                          bottom: 8,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _confirmDisbursement,
                          icon: const Icon(Icons.payments, size: 18),
                          label: const Text('Décaisser'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _getStatusColor(loan!.statut),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: loan != null
                          ? [
                              _getStatusColor(loan!.statut),
                              _getStatusColor(loan!.statut).withOpacity(0.8),
                            ]
                          : [Colors.blue.shade600, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (loan != null) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(loan!.statut),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getStatusText(loan!.statut),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${loan!.montant.toStringAsFixed(0)}€ sur ${loan!.dureeMois} mois',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content avec onglets modernes
            SliverToBoxAdapter(
              child: isLoading
                  ? const SizedBox(
                      height: 400,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : loan == null
                  ? const SizedBox(
                      height: 400,
                      child: Center(child: Text('Prêt non trouvé')),
                    )
                  : Column(
                      children: [
                        // Onglets modernes
                        Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.purple.shade400,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey[600],
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Informations'),
                              Tab(text: 'Échéancier'),
                            ],
                          ),
                        ),
                        // Contenu des onglets
                        SizedBox(
                          height: 600,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildLoanInfoTab(),
                              _buildPaymentScheduleTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanInfoTab() {
    if (loan == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note admin si présente
          if (loan!.noteAdmin != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.comment, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Note de l\'administrateur',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loan!.noteAdmin!,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Alerte de décaissement pour admin si prêt approuvé
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isAdmin && loan!.statut == LoanStatus.approuve) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.payments,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Prêt approuvé - Décaissement requis',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ce prêt a été approuvé et attend votre confirmation de décaissement. Cliquez sur le bouton "DÉCAISSER" en haut à droite pour procéder.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _confirmDisbursement,
                          icon: const Icon(Icons.payments),
                          label: const Text('Confirmer le décaissement'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Section remboursement anticipé
          if (loan != null &&
              loan!.allowsEarlyRepayment &&
              !loan!.hasEarlyRepayment)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.speed,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Remboursement anticipé',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vous pouvez rembourser une partie du capital par anticipation pour réduire la durée de votre prêt. Les intérêts totaux restent identiques.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showEarlyRepaymentDialog,
                      icon: const Icon(Icons.speed),
                      label: const Text('Simuler un remboursement anticipé'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Section pour les prêts avec remboursement anticipé effectué
          if (loan != null && loan!.hasEarlyRepayment)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Remboursement anticipé effectué',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Remboursement anticipé de ${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(loan!.montantRemboursementAnticipe)} effectué le ${DateFormat('dd/MM/yyyy').format(loan!.dateRemboursementAnticipe!)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nouvelle durée: ${loan!.dureeEffective} mois (économie de ${loan!.dureeMois - loan!.dureeEffective} mois)',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Bouton d'annulation pour les prêts éligibles
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              // Logique d'annulation différente selon le rôle
              final canCancel =
                  loan != null &&
                  ((authProvider.isAdmin && loan!.canBeCancelledByAdmin) ||
                      (!authProvider.isAdmin &&
                          loan!.canBeCancelledByBorrower));

              if (canCancel) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.cancel_outlined,
                              color: Colors.red.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            authProvider.isAdmin
                                ? 'Annulation du prêt (Admin)'
                                : 'Annulation du prêt',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        authProvider.isAdmin
                            ? 'En tant qu\'administrateur, vous pouvez annuler ce prêt à tout moment. Cette action est irréversible et l\'emprunteur sera notifié.'
                            : 'Vous pouvez annuler ce prêt tant qu\'il n\'a pas été approuvé. Cette action est irréversible.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showCancelLoanDialog,
                          icon: const Icon(Icons.cancel),
                          label: Text(
                            authProvider.isAdmin
                                ? 'Annuler ce prêt (Admin)'
                                : 'Annuler ce prêt',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ), // Informations principales modernes
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Détail du prêt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildModernInfoRow(
                  'Montant demandé',
                  '${loan!.montant.toStringAsFixed(0)}€',
                  Icons.euro,
                  Colors.green,
                ),
                _buildModernInfoRow(
                  'Taux d\'intérêt',
                  '${loan!.tauxAnnuel.toStringAsFixed(0)}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildModernInfoRow(
                  'Coût intérêt',
                  '${loan!.coutTotalEstime.toStringAsFixed(0)}€',
                  Icons.calculate,
                  Colors.red,
                ),
                _buildModernInfoRow(
                  'Coût total',
                  '${(loan!.montant + loan!.coutTotalEstime).toStringAsFixed(0)}€',
                  Icons.account_balance_wallet,
                  Colors.purple,
                ),
                _buildModernInfoRow(
                  'Mensualité',
                  '${loan!.mensualite.toStringAsFixed(0)}€',
                  Icons.payment,
                  Colors.blue,
                ),
                const Divider(height: 32),
                _buildModernInfoRow(
                  'Durée',
                  '${loan!.dureeMois} mois',
                  Icons.schedule,
                  Colors.teal,
                ),
                if (loan!.ribEmprunteur.isNotEmpty) ...[
                  const Divider(height: 32),
                  _buildModernInfoRow(
                    'RIB / IBAN',
                    loan!.ribEmprunteur,
                    Icons.account_balance,
                    Colors.indigo,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dates importantes modernes
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.teal, Colors.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Dates importantes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildModernInfoRow(
                  'Demande créée',
                  DateFormat('dd/MM/yyyy à HH:mm').format(loan!.createdAt),
                  Icons.create,
                  Colors.blue,
                ),
                _buildModernInfoRow(
                  'Date souhaitée',
                  DateFormat('dd/MM/yyyy').format(loan!.dateSouhaitee),
                  Icons.event,
                  Colors.purple,
                ),
                if (loan!.approvedAt != null)
                  _buildModernInfoRow(
                    'Approuvé le',
                    DateFormat('dd/MM/yyyy à HH:mm').format(loan!.approvedAt!),
                    Icons.check_circle,
                    Colors.green,
                  ),
                if (loan!.disbursedAt != null)
                  _buildModernInfoRow(
                    'Décaissé le',
                    DateFormat('dd/MM/yyyy à HH:mm').format(loan!.disbursedAt!),
                    Icons.payment,
                    Colors.teal,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentScheduleTab() {
    if (paymentSchedule == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Échéancier non disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'L\'échéancier sera disponible une fois le prêt approuvé.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Résumé de l'échéancier
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résumé de l\'échéancier',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${paymentSchedule!.totalCapital.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text('Capital'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${paymentSchedule!.totalInterets.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text('Intérêts'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${paymentSchedule!.totalMontant.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text('Total'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Liste des échéances
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Détail des échéances',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PaymentScheduleScreen(
                                paymentSchedule: paymentSchedule!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Voir tout'),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paymentSchedule!.echeances.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final echeance = paymentSchedule!.echeances[index];
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final isAdmin = authProvider.isAdmin;

                    final isPaid = echeance.statut == PaymentStatus.payee;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.green.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isPaid
                            ? Border.all(
                                color: Colors.green.shade200,
                                width: 1.5,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: isPaid
                                ? Colors.green.withOpacity(0.1)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: isPaid ? 12 : 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Avatar avec style Revolut amélioré
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isPaid
                                      ? [
                                          Colors.green.shade400,
                                          Colors.green.shade600,
                                        ]
                                      : [
                                          _getPaymentStatusColor(
                                            echeance.statut,
                                          ),
                                          _getPaymentStatusColor(
                                            echeance.statut,
                                          ).withOpacity(0.8),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: isPaid
                                        ? Colors.green.withOpacity(0.3)
                                        : _getPaymentStatusColor(
                                            echeance.statut,
                                          ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isPaid
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 24,
                                        weight: 700,
                                      )
                                    : Text(
                                        '${echeance.numeroEcheance}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Informations principales avec style conditionnel
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(echeance.dateEcheance),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isPaid
                                                ? Colors.green.shade700
                                                : Colors.black87,
                                            decoration: isPaid
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                            decorationColor:
                                                Colors.green.shade400,
                                            decorationThickness: 2,
                                          ),
                                        ),
                                      ),
                                      if (isPaid)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.green.shade400,
                                                Colors.green.shade600,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'PAYÉ',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Capital: ${echeance.montantCapital.toStringAsFixed(2)} € • Intérêts: ${echeance.montantInterets.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isPaid
                                          ? Colors.green.shade600
                                          : Colors.grey[600],
                                      decoration: isPaid
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: Colors.green.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reste: ${echeance.capitalRestantDu.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isPaid
                                          ? Colors.green.shade500
                                          : Colors.grey[500],
                                      decoration: isPaid
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: Colors.green.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Montant et statut/bouton à droite
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${echeance.montantTotal.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isPaid
                                        ? Colors.green.shade700
                                        : Colors.black87,
                                    decoration: isPaid
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    decorationColor: Colors.green.shade400,
                                    decorationThickness: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Affichage conditionnel selon le statut
                                if (isPaid)
                                  // Badge de confirmation style Revolut pour échéance payée
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.green.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Payé',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isAdmin)
                                  // Bouton admin style Revolut pour marquer comme payé
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF00D4FF),
                                          Color(0xFF3B82F6),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF3B82F6,
                                          ).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            _markPaymentAsPaid(echeance),
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'Marquer payé',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(LoanStatus status) {
    switch (status) {
      case LoanStatus.brouillon:
        return Icons.edit_outlined;
      case LoanStatus.soumis:
        return Icons.send_outlined;
      case LoanStatus.enRevue:
        return Icons.visibility_outlined;
      case LoanStatus.approuve:
        return Icons.check_circle_outline;
      case LoanStatus.refuse:
        return Icons.cancel_outlined;
      case LoanStatus.decaissementEffectue:
        return Icons.payment_outlined;
      case LoanStatus.enCours:
        return Icons.trending_up_outlined;
      case LoanStatus.solde:
        return Icons.task_alt_outlined;
      case LoanStatus.enRetard:
        return Icons.warning_outlined;
      case LoanStatus.annule:
        return Icons.block_outlined;
      case LoanStatus.ferme:
        return Icons.lock_outlined;
    }
  }

  Color _getStatusColor(LoanStatus status) {
    switch (status) {
      case LoanStatus.brouillon:
        return Colors.grey;
      case LoanStatus.soumis:
        return Colors.blue;
      case LoanStatus.enRevue:
        return Colors.orange;
      case LoanStatus.approuve:
        return Colors.green;
      case LoanStatus.refuse:
        return Colors.red;
      case LoanStatus.decaissementEffectue:
        return Colors.teal;
      case LoanStatus.enCours:
        return Colors.indigo;
      case LoanStatus.solde:
        return Colors.green.shade700;
      case LoanStatus.enRetard:
        return Colors.red.shade700;
      case LoanStatus.annule:
        return Colors.grey.shade700;
      case LoanStatus.ferme:
        return Colors.purple.shade700;
    }
  }

  String _getStatusText(LoanStatus status) {
    switch (status) {
      case LoanStatus.brouillon:
        return 'Brouillon';
      case LoanStatus.soumis:
        return 'Soumis';
      case LoanStatus.enRevue:
        return 'En révision';
      case LoanStatus.approuve:
        return 'Approuvé';
      case LoanStatus.refuse:
        return 'Refusé';
      case LoanStatus.decaissementEffectue:
        return 'Décaissement effectué';
      case LoanStatus.enCours:
        return 'En cours';
      case LoanStatus.solde:
        return 'Soldé';
      case LoanStatus.enRetard:
        return 'En retard';
      case LoanStatus.annule:
        return 'Annulé';
      case LoanStatus.ferme:
        return 'Clôturé';
    }
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.aVenir:
        return Colors.grey;
      case PaymentStatus.echue:
        return Colors.orange;
      case PaymentStatus.payee:
        return Colors.green;
      case PaymentStatus.enRetard:
        return Colors.red;
      case PaymentStatus.reportee:
        return Colors.blue;
    }
  }
}
