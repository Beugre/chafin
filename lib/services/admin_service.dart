import '../utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/loan_model.dart';
import '../models/repayment_model.dart';
import '../models/schedule_item_model.dart';
import 'repayment_service.dart';
import 'cleanup_service.dart';
import 'email_service.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RepaymentService _repaymentService = RepaymentService();
  final CleanupService _cleanupService = CleanupService();

  /// Créer un compte administrateur
  Future<UserModel> createAdminAccount({
    required String email,
    required String password,
    required String nom,
    required String telephone,
    required String adresse,
    required UserRole role,
  }) async {
    try {
      debugLog('=== AdminService.createAdminAccount ===');
      debugLog('Email: $email, Rôle: $role');

      // Créer l'utilisateur dans Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugLog('Firebase Auth créé: ${result.user?.uid}');

      if (result.user != null) {
        final user = UserModel(
          id: result.user!.uid,
          nom: nom,
          prenom: 'Admin',
          email: email.trim(),
          telephone: telephone,
          adresse: adresse,
          role: role,
          createdAt: DateTime.now(),
        );

        // Sauvegarder dans Firestore
        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(user.toJson());

        debugLog('Compte admin créé avec succès');
        return user;
      } else {
        throw Exception('Erreur lors de la création du compte Firebase');
      }
    } catch (e) {
      debugLog('Erreur création admin: $e');
      throw Exception('Erreur lors de la création du compte admin: $e');
    }
  }

  /// Récupérer tous les prêts (pour admin)
  Future<List<LoanModel>> getAllLoans() async {
    try {
      debugLog('=== AdminService.getAllLoans ===');

      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .orderBy('createdAt', descending: true)
          .get();

      final loans = snapshot.docs
          .map((doc) => LoanModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      debugLog('Total prêts récupérés: ${loans.length}');

      return loans;
    } catch (e) {
      debugLog('Erreur récupération prêts: $e');
      throw Exception('Erreur lors de la récupération des prêts: $e');
    }
  }

  /// Récupérer les prêts par statut
  Future<List<LoanModel>> getLoansByStatus(LoanStatus status) async {
    try {
      debugLog('=== AdminService.getLoansByStatus ===');
      debugLog('Statut recherché: $status');

      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .where('statut', isEqualTo: status.name)
          .get();

      final loans = snapshot.docs
          .map((doc) => LoanModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      debugLog('Prêts trouvés avec statut $status: ${loans.length}');

      // Trier par date de création
      loans.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return loans;
    } catch (e) {
      debugLog('Erreur récupération prêts par statut: $e');
      throw Exception('Erreur lors de la récupération des prêts: $e');
    }
  }

  /// Approuver un prêt
  Future<void> approveLoan(String loanId) async {
    try {
      debugLog('=== AdminService.approveLoan ===');
      debugLog('ID prêt: $loanId');

      // Récupérer les détails du prêt avant mise à jour
      final loanDoc = await _firestore.collection('loans').doc(loanId).get();
      if (!loanDoc.exists) {
        throw Exception('Prêt non trouvé');
      }

      final loan = LoanModel.fromJson(loanDoc.data()!);

      await _firestore.collection('loans').doc(loanId).update({
        'statut': LoanStatus.approuve.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
      });

      debugLog('Prêt approuvé avec succès');

      // ✨ NOUVEAU : Envoi d'email d'approbation
      try {
        // Récupérer les infos de l'emprunteur
        final userDoc = await _firestore
            .collection('users')
            .doc(loan.userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final userEmail = userData['email'] as String?;
          final userName = userData['nom'] as String? ?? 'Cher client';

          if (userEmail != null) {
            debugLog('📧 Envoi d\'email d\'approbation à: $userEmail');

            await EmailService.sendLoanNotificationEmail(
              to: userEmail,
              userName: userName,
              type: LoanEmailType.loanApproved,
              loanData: {
                'amount': loan.montant.toStringAsFixed(0),
                'duration': loan.dureeMois.toString(),
                'rate': loan.tauxAnnuel.toStringAsFixed(1),
                'firstPayment': loan.dateSouhaitee.toIso8601String().split(
                  'T',
                )[0],
              },
            );
            debugLog('✅ Email d\'approbation envoyé avec succès');
          }
        }
      } catch (emailError) {
        debugLog('❌ Erreur lors de l\'envoi d\'email d\'approbation: $emailError');
        // Ne pas faire échouer l'approbation si l'email échoue
      }
    } catch (e) {
      debugLog('Erreur approbation prêt: $e');
      throw Exception('Erreur lors de l\'approbation du prêt: $e');
    }
  }

  /// Rejeter un prêt
  Future<void> rejectLoan(String loanId, String reason) async {
    try {
      debugLog('=== AdminService.rejectLoan ===');
      debugLog('ID prêt: $loanId, Raison: $reason');

      // Récupérer les détails du prêt avant mise à jour
      final loanDoc = await _firestore.collection('loans').doc(loanId).get();
      if (!loanDoc.exists) {
        throw Exception('Prêt non trouvé');
      }

      final loan = LoanModel.fromJson(loanDoc.data()!);

      await _firestore.collection('loans').doc(loanId).update({
        'statut': LoanStatus.refuse.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });

      debugLog('Prêt rejeté avec succès');

      // ✨ NOUVEAU : Envoi d'email de refus
      try {
        // Récupérer les infos de l'emprunteur
        final userDoc = await _firestore
            .collection('users')
            .doc(loan.userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final userEmail = userData['email'] as String?;
          final userName = userData['nom'] as String? ?? 'Cher client';

          if (userEmail != null) {
            debugLog('📧 Envoi d\'email de refus à: $userEmail');

            await EmailService.sendLoanNotificationEmail(
              to: userEmail,
              userName: userName,
              type: LoanEmailType.loanRejected,
              loanData: {
                'amount': loan.montant.toStringAsFixed(0),
                'duration': loan.dureeMois.toString(),
                'reason': reason,
              },
            );
            debugLog('✅ Email de refus envoyé avec succès');
          }
        }
      } catch (emailError) {
        debugLog('❌ Erreur lors de l\'envoi d\'email de refus: $emailError');
        // Ne pas faire échouer le refus si l'email échoue
      }
    } catch (e) {
      debugLog('Erreur rejet prêt: $e');
      throw Exception('Erreur lors du rejet du prêt: $e');
    }
  }

  /// Récupérer tous les utilisateurs
  Future<List<UserModel>> getAllUsers() async {
    try {
      debugLog('=== AdminService.getAllUsers ===');

      final QuerySnapshot snapshot = await _firestore.collection('users').get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      debugLog('Total utilisateurs: ${users.length}');

      // Trier par date de création
      users.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return users;
    } catch (e) {
      debugLog('Erreur récupération utilisateurs: $e');
      throw Exception('Erreur lors de la récupération des utilisateurs: $e');
    }
  }

  /// Récupérer les statistiques globales
  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      debugLog('=== AdminService.getGlobalStats ===');

      // Récupérer tous les prêts avec gestion d'erreur
      final loansSnapshot = await _firestore.collection('loans').get();
      final loans = <LoanModel>[];

      for (var doc in loansSnapshot.docs) {
        try {
          debugLog('📄 Traitement loan document: ${doc.id}');
          debugLog('📊 Données brutes: ${doc.data()}');

          final loan = LoanModel.fromJson(doc.data());
          loans.add(loan);
          debugLog('✅ Loan ajouté: ${loan.id}');
        } catch (e) {
          debugLog('❌ Erreur lors du parsing du loan ${doc.id}: $e');
          debugLog('📄 Données problématiques: ${doc.data()}');
          // Continue avec les autres documents
        }
      }

      // Récupérer tous les utilisateurs avec gestion d'erreur
      final usersSnapshot = await _firestore.collection('users').get();
      final users = <UserModel>[];

      for (var doc in usersSnapshot.docs) {
        try {
          debugLog('📄 Traitement user document: ${doc.id}');
          final rawData = doc.data();
          debugLog('📊 Données brutes: $rawData');

          // Vérifier chaque champ individuellement
          debugLog('🔍 Vérification champs:');
          debugLog('  - id: ${rawData['id']} (${rawData['id'].runtimeType})');
          debugLog('  - nom: ${rawData['nom']} (${rawData['nom'].runtimeType})');
          debugLog(
            '  - email: ${rawData['email']} (${rawData['email'].runtimeType})',
          );
          debugLog(
            '  - telephone: ${rawData['telephone']} (${rawData['telephone'].runtimeType})',
          );
          debugLog(
            '  - adresse: ${rawData['adresse']} (${rawData['adresse'].runtimeType})',
          );
          debugLog(
            '  - role: ${rawData['role']} (${rawData['role'].runtimeType})',
          );
          debugLog(
            '  - createdAt: ${rawData['createdAt']} (${rawData['createdAt'].runtimeType})',
          );

          final user = UserModel.fromJson(rawData);
          users.add(user);
          debugLog('✅ User ajouté: ${user.nom} - ${user.role}');
        } catch (e) {
          debugLog('❌ Erreur lors du parsing du user ${doc.id}: $e');
          debugLog('📄 Données problématiques: ${doc.data()}');
          // Continue avec les autres documents
        }
      }

      // Calculer les statistiques
      final stats = {
        'totalLoans': loans.length,
        'totalUsers': users.length,
        'pendingLoans': loans
            .where((loan) => loan.statut == LoanStatus.soumis)
            .length,
        'approvedLoans': loans
            .where((loan) => loan.statut == LoanStatus.approuve)
            .length,
        'rejectedLoans': loans
            .where((loan) => loan.statut == LoanStatus.refuse)
            .length,
        'totalAmount': loans
            .where((loan) => loan.statut == LoanStatus.approuve)
            .fold(0.0, (sum, loan) => sum + loan.montant),
        'borrowers': users
            .where((user) => user.role == UserRole.borrower)
            .length,
        'admins': users.where((user) => user.role == UserRole.admin).length,
        'superAdmins': users
            .where((user) => user.role == UserRole.superAdmin)
            .length,
      };

      debugLog('Statistiques calculées: $stats');
      return stats;
    } catch (e) {
      debugLog('Erreur calcul statistiques: $e');
      throw Exception('Erreur lors du calcul des statistiques: $e');
    }
  }

  /// Récupérer les données d'un utilisateur par ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugLog('Erreur récupération utilisateur: $e');
      throw Exception('Erreur lors de la récupération de l\'utilisateur: $e');
    }
  }

  /// Confirmer le décaissement d'un prêt approuvé
  Future<void> confirmLoanDisbursement(
    String loanId, {
    String? referenceDecaissement, // OPTIONNEL maintenant
    String? noteAdmin,
  }) async {
    try {
      debugLog('=== AdminService.confirmLoanDisbursement ===');
      debugLog('Prêt ID: $loanId, Référence: $referenceDecaissement');

      // Récupérer le prêt avant mise à jour pour l'email
      final loanDoc = await _firestore.collection('loans').doc(loanId).get();
      if (!loanDoc.exists) {
        throw Exception('Prêt non trouvé');
      }

      final loan = LoanModel.fromJson(loanDoc.data()!);

      // Mettre à jour le prêt avec référence automatique si vide
      final finalReference = referenceDecaissement?.isNotEmpty == true
          ? referenceDecaissement
          : 'AUTO-${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('loans').doc(loanId).update({
        'statut': LoanStatus.decaissementEffectue.toString().split('.').last,
        'disbursedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'referenceDecaissement': finalReference,
        'noteAdmin': noteAdmin,
      });

      // Générer l'échéancier de remboursement
      await _repaymentService.generateRepaymentSchedule(loan);

      // Mettre le prêt en cours
      await _firestore.collection('loans').doc(loanId).update({
        'statut': LoanStatus.enCours.toString().split('.').last,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      debugLog('Décaissement confirmé et échéancier généré');

      // ✨ NOUVEAU : Envoi d'email de décaissement
      try {
        // Récupérer les infos de l'emprunteur
        final userDoc = await _firestore
            .collection('users')
            .doc(loan.userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final userEmail = userData['email'] as String?;
          final userName = userData['nom'] as String? ?? 'Cher client';

          if (userEmail != null) {
            debugLog('📧 Envoi d\'email de décaissement à: $userEmail');

            // Calculer la date de première échéance (généralement 30 jours après)
            final firstPaymentDate = DateTime.now().add(
              const Duration(days: 30),
            );

            await EmailService.sendLoanNotificationEmail(
              to: userEmail,
              userName: userName,
              type: LoanEmailType.loanDisbursed,
              loanData: {
                'amount': loan.montant.toStringAsFixed(0),
                'disbursementDate': DateTime.now().toIso8601String().split(
                  'T',
                )[0],
                'reference': finalReference,
                'firstPaymentDate': firstPaymentDate.toIso8601String().split(
                  'T',
                )[0],
              },
            );
            debugLog('✅ Email de décaissement envoyé avec succès');
          }
        }
      } catch (emailError) {
        debugLog(
          '❌ Erreur lors de l\'envoi d\'email de décaissement: $emailError',
        );
        // Ne pas faire échouer le décaissement si l'email échoue
      }
    } catch (e) {
      debugLog('Erreur confirmation décaissement: $e');
      throw Exception('Erreur lors de la confirmation du décaissement: $e');
    }
  }

  /// Récupérer l'échéancier d'un prêt
  Future<List<RepaymentModel>> getLoanRepayments(String loanId) async {
    return await _repaymentService.getLoanRepayments(loanId);
  }

  /// Marquer une mensualité comme payée
  Future<void> markRepaymentAsPaid(
    String repaymentId,
    double montantPaye, {
    String? referencePaiement,
    String? noteAdmin,
  }) async {
    return await _repaymentService.markRepaymentAsPaid(
      repaymentId,
      montantPaye,
      referencePaiement: referencePaiement,
      noteAdmin: noteAdmin,
    );
  }

  /// Récupérer les mensualités en retard
  Future<List<RepaymentModel>> getOverdueRepayments() async {
    return await _repaymentService.getOverdueRepayments();
  }

  /// Nettoyer les échéanciers dupliqués pour un prêt
  Future<void> cleanupLoanRepayments(String loanId) async {
    await _cleanupService.cleanupLoanRepayments(loanId);
  }

  /// Nettoyer tous les échéanciers dupliqués
  Future<void> cleanupAllDuplicateRepayments() async {
    await _cleanupService.cleanupDuplicateRepayments();
  }

  /// Récupérer tous les échéanciers (schedules) Firebase
  Future<List<ScheduleItemModel>> getAllSchedules() async {
    try {
      debugLog('=== AdminService.getAllSchedules ===');

      final QuerySnapshot snapshot = await _firestore
          .collection('schedules')
          .get();

      final schedules = <ScheduleItemModel>[];

      for (var doc in snapshot.docs) {
        try {
          debugLog('📄 Traitement schedule document: ${doc.id}');

          final data = doc.data() as Map<String, dynamic>;

          // ⚠️ VÉRIFICATION DES CHAMPS OBLIGATOIRES
          // Si loanId manque, c'est un schedule mal formé (marqué manuellement sans context complet)
          if (!data.containsKey('loanId') || data['loanId'] == null) {
            debugLog(
              '⚠️ Schedule ${doc.id} ignoré: manque loanId (schedule marqué manuellement sans contexte)',
            );
            continue;
          }
          if (!data.containsKey('dueDate') || data['dueDate'] == null) {
            debugLog('⚠️ Schedule ${doc.id} ignoré: manque dueDate');
            continue;
          }
          if (!data.containsKey('numero') || data['numero'] == null) {
            debugLog('⚠️ Schedule ${doc.id} ignoré: manque numero');
            continue;
          }
          if (!data.containsKey('principal') || data['principal'] == null) {
            debugLog('⚠️ Schedule ${doc.id} ignoré: manque principal');
            continue;
          }
          if (!data.containsKey('interet') || data['interet'] == null) {
            debugLog('⚠️ Schedule ${doc.id} ignoré: manque interet');
            continue;
          }
          if (!data.containsKey('total') || data['total'] == null) {
            debugLog('⚠️ Schedule ${doc.id} ignoré: manque total');
            continue;
          }

          // Convertir les timestamps Firestore en DateTime
          if (data['dueDate'] is Timestamp) {
            data['dueDate'] = (data['dueDate'] as Timestamp)
                .toDate()
                .toIso8601String();
          } else if (data['dueDate'] is String) {
            // Déjà au bon format, ne rien faire
            // Mais vérifier que c'est une date valide
            try {
              DateTime.parse(data['dueDate'] as String);
            } catch (e) {
              debugLog('⚠️ Schedule ${doc.id} ignoré: dueDate invalide');
              continue;
            }
          }

          // Gérer createdAt (peut être null si serverTimestamp pas encore résolu)
          if (data['createdAt'] == null) {
            data['createdAt'] = DateTime.now().toIso8601String();
          } else if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          } else if (data['createdAt'] is String) {
            // Déjà au bon format
          }

          // Gérer updatedAt (peut être null)
          if (data['updatedAt'] == null) {
            // Ne pas ajouter ce champ s'il est null
            data.remove('updatedAt');
          } else if (data['updatedAt'] is Timestamp) {
            data['updatedAt'] = (data['updatedAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          } else if (data['updatedAt'] is String) {
            // Déjà au bon format
          }

          // Gérer paidAt (optionnel)
          if (data['paidAt'] != null && data['paidAt'] is Timestamp) {
            data['paidAt'] = (data['paidAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          } else if (data['paidAt'] is String) {
            // Déjà au bon format
          } else if (data['paidAt'] == null) {
            // Laisser null
          }

          // Ajouter l'ID du document
          data['id'] = doc.id;

          final schedule = ScheduleItemModel.fromJson(data);
          schedules.add(schedule);
          debugLog(
            '✅ Schedule ajouté: ${schedule.id} (${schedule.isPaid ? "payé" : "non payé"})',
          );
        } catch (e) {
          debugLog('❌ Erreur lors du parsing du schedule ${doc.id}: $e');
          debugLog('📄 Données problématiques: ${doc.data()}');
          // Continue avec les autres documents
        }
      }

      debugLog('Total schedules récupérés: ${schedules.length}');
      return schedules;
    } catch (e) {
      debugLog('Erreur récupération schedules: $e');
      throw Exception('Erreur lors de la récupération des échéanciers: $e');
    }
  }

  /// Ajoute une nouvelle échéance dans Firestore
  Future<void> addScheduleItem(ScheduleItemModel schedule) async {
    try {
      await _firestore.collection('schedules').add({
        'loanId': schedule.loanId,
        'numero': schedule.numero,
        'dueDate': Timestamp.fromDate(schedule.dueDate),
        'principal': schedule.principal,
        'interet': schedule.interet,
        'total': schedule.total,
        'isPaid': schedule.isPaid,
        'paidAt': schedule.paidAt != null
            ? Timestamp.fromDate(schedule.paidAt!)
            : null,
        'paidAmount': schedule.paidAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout de l\'échéance: $e');
    }
  }

  /// Modifie la date de première échéance et recalcule toutes les dates suivantes
  /// Exemple : Échéancier 1 au 05/11 devient 31/10 → Échéancier 2 passe de 05/12 à 30/11
  Future<void> updateScheduleStartDate({
    required String loanId,
    required DateTime newStartDate,
  }) async {
    try {
      debugLog('=== AdminService.updateScheduleStartDate ===');
      debugLog('Prêt: $loanId');
      debugLog('Nouvelle date de début: ${newStartDate.toIso8601String()}');

      // Récupérer le prêt pour avoir les infos de calcul
      final loanDoc = await _firestore.collection('loans').doc(loanId).get();
      if (!loanDoc.exists) {
        throw Exception('Prêt non trouvé');
      }
      final loanData = loanDoc.data()!;

      // Récupérer tous les échéanciers du prêt
      final schedulesSnapshot = await _firestore
          .collection('schedules')
          .where('loanId', isEqualTo: loanId)
          .orderBy('numero')
          .get();

      if (schedulesSnapshot.docs.isEmpty) {
        throw Exception('Aucun échéancier trouvé pour ce prêt');
      }

      debugLog('Échéanciers trouvés: ${schedulesSnapshot.docs.length}');

      // 1. SAUVEGARDER les statuts de paiement
      final Map<int, Map<String, dynamic>> paidStatus = {};
      for (final doc in schedulesSnapshot.docs) {
        final data = doc.data();
        final numero = data['numero'] as int;
        final isPaid = data['isPaid'] as bool? ?? false;

        if (isPaid) {
          paidStatus[numero] = {
            'isPaid': true,
            'paidAt': data['paidAt'],
            'paidAmount': data['paidAmount'],
          };
          debugLog('  ✅ Échéance #$numero était payée - statut sauvegardé');
        }
      }

      debugLog('💾 ${paidStatus.length} paiements sauvegardés');

      // 2. SUPPRIMER toutes les anciennes échéances
      final batch = _firestore.batch();
      for (final doc in schedulesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugLog(
        '🗑️ ${schedulesSnapshot.docs.length} anciennes échéances supprimées',
      );

      // 3. RECRÉER les échéances avec les nouvelles dates
      final montant = (loanData['montant'] as num).toDouble();
      final tauxAnnuel = (loanData['tauxAnnuel'] as num).toDouble();
      final dureeMois = loanData['dureeMois'] as int;

      // Calculer avec formule TAUX SIMPLE
      final interetsTotal = montant * (tauxAnnuel / 100);
      final montantTotal = montant + interetsTotal;
      final mensualite = montantTotal / dureeMois;

      for (int i = 0; i < dureeMois; i++) {
        final numero = i + 1;
        final dueDate = DateTime(
          newStartDate.year,
          newStartDate.month + i,
          newStartDate.day,
        );

        // Restaurer le statut de paiement si existant
        final wasPaid = paidStatus.containsKey(numero);

        await _firestore.collection('schedules').add({
          'loanId': loanId,
          'numero': numero,
          'dueDate': Timestamp.fromDate(dueDate),
          'principal': montant / dureeMois,
          'interet': interetsTotal / dureeMois,
          'total': mensualite,
          'isPaid': wasPaid,
          'paidAt': wasPaid ? paidStatus[numero]!['paidAt'] : null,
          'paidAmount': wasPaid ? paidStatus[numero]!['paidAmount'] : null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugLog(
          '  ✅ Échéance #$numero créée: $dueDate (${wasPaid ? "payée" : "non payée"})',
        );
      }

      // 4. Mettre à jour la date de premier remboursement dans le prêt
      await _firestore.collection('loans').doc(loanId).update({
        'datePremierRemboursement': Timestamp.fromDate(newStartDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugLog(
        '✅ ${dureeMois} échéances recréées avec ${paidStatus.length} paiements préservés',
      );
    } catch (e) {
      debugLog('❌ Erreur lors de la mise à jour des dates: $e');
      throw Exception(
        'Erreur lors de la mise à jour des dates d\'échéancier: $e',
      );
    }
  }
}
