import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan_model.dart';
import '../models/repayment_model.dart';
import 'repayment_service.dart';

class BorrowerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RepaymentService _repaymentService = RepaymentService();

  /// Récupérer tous les prêts de l'utilisateur connecté
  Future<List<LoanModel>> getUserLoans(String userId) async {
    try {
      print('=== BorrowerService.getUserLoans ===');
      print('User ID: $userId');

      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .where('userId', isEqualTo: userId)
          .get();

      final loans = snapshot.docs
          .map((doc) => LoanModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Trier en mémoire par date de création
      loans.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('Prêts utilisateur trouvés: ${loans.length}');
      for (final loan in loans) {
        print('- Prêt ${loan.id}: ${loan.montant}€, Statut: ${loan.statut}');
      }

      return loans;
    } catch (e) {
      print('Erreur récupération prêts utilisateur: $e');
      throw Exception('Erreur lors de la récupération des prêts: $e');
    }
  }

  /// Récupérer les prêts par statut pour un utilisateur
  Future<List<LoanModel>> getUserLoansByStatus(
    String userId,
    LoanStatus status,
  ) async {
    try {
      print('=== BorrowerService.getUserLoansByStatus ===');
      print('User ID: $userId, Statut: $status');

      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .where('userId', isEqualTo: userId)
          .where('statut', isEqualTo: status.toString().split('.').last)
          .get();

      final loans = snapshot.docs
          .map((doc) => LoanModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Trier en mémoire par date de création
      loans.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('Prêts avec statut $status: ${loans.length}');

      return loans;
    } catch (e) {
      print('Erreur récupération prêts par statut: $e');
      throw Exception('Erreur lors de la récupération des prêts: $e');
    }
  }

  /// Récupérer l'échéancier des remboursements pour un utilisateur
  Future<List<RepaymentModel>> getUserRepayments(String userId) async {
    try {
      return await _repaymentService.getUserRepayments(userId);
    } catch (e) {
      print('Erreur récupération échéancier: $e');
      throw Exception('Erreur lors de la récupération de l\'échéancier: $e');
    }
  }

  /// Récupérer les remboursements pour un prêt spécifique
  Future<List<RepaymentModel>> getLoanRepayments(String loanId) async {
    try {
      return await _repaymentService.getLoanRepayments(loanId);
    } catch (e) {
      print('Erreur récupération remboursements prêt: $e');
      throw Exception('Erreur lors de la récupération des remboursements: $e');
    }
  }

  /// Récupérer le détail d'un prêt spécifique
  Future<LoanModel?> getLoanDetails(String loanId, String userId) async {
    try {
      print('=== BorrowerService.getLoanDetails ===');
      print('Loan ID: $loanId, User ID: $userId');

      final DocumentSnapshot doc = await _firestore
          .collection('loans')
          .doc(loanId)
          .get();

      if (doc.exists) {
        final loan = LoanModel.fromJson(doc.data() as Map<String, dynamic>);

        // Vérifier que le prêt appartient à l'utilisateur
        if (loan.userId == userId) {
          return loan;
        } else {
          throw Exception('Accès non autorisé à ce prêt');
        }
      }

      return null;
    } catch (e) {
      print('Erreur récupération détail prêt: $e');
      throw Exception('Erreur lors de la récupération du prêt: $e');
    }
  }

  /// Obtenir un résumé des prêts de l'utilisateur
  Future<Map<String, dynamic>> getUserLoansSummary(String userId) async {
    try {
      print('=== BorrowerService.getUserLoansSummary ===');

      final loans = await getUserLoans(userId);
      final repayments = await getUserRepayments(userId);

      final summary = {
        'totalLoans': loans.length,
        'pendingLoans': loans.where((l) => l.isPending).length,
        'approvedLoans': loans.where((l) => l.isApproved).length,
        'activeLoans': loans.where((l) => l.isActive).length,
        'completedLoans': loans.where((l) => l.isCompleted).length,
        'rejectedLoans': loans
            .where((l) => l.statut == LoanStatus.refuse)
            .length,
        'totalBorrowed': loans
            .where(
              (l) =>
                  l.statut == LoanStatus.enCours ||
                  l.statut == LoanStatus.solde,
            )
            .fold(0.0, (sum, loan) => sum + loan.montant),
        'totalRepaid': repayments
            .where((r) => r.isPaid)
            .fold(0.0, (sum, repayment) => sum + repayment.montantPaye),
        'pendingRepayments': repayments.where((r) => r.isPending).length,
        'overdueRepayments': repayments.where((r) => r.isOverdue).length,
        'nextPaymentDue': _getNextPaymentDue(repayments),
      };

      print('Résumé utilisateur: $summary');
      return summary;
    } catch (e) {
      print('Erreur calcul résumé: $e');
      throw Exception('Erreur lors du calcul du résumé: $e');
    }
  }

  /// Trouver la prochaine échéance à payer
  DateTime? _getNextPaymentDue(List<RepaymentModel> repayments) {
    final pending = repayments.where((r) => r.isPending).toList();

    if (pending.isEmpty) return null;

    pending.sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    return pending.first.dateEcheance;
  }
}
