import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/loan_model.dart';
import '../models/schedule_item_model.dart';
import '../models/notification_model.dart';
import 'loan_calculation_service.dart';
import 'app_notification_service.dart';
import 'email_service.dart';

class LoanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Met à jour un champ unique d'un prêt (ex: emailsDisabled, penaltiesDisabled)
  Future<void> updateLoanField(
    String loanId,
    String field,
    dynamic value,
  ) async {
    final Map<String, dynamic> updateData = {
      field: value,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _firestore.collection('loans').doc(loanId).update(updateData);
  }

  /// Modifier le taux d'intérêt d'un prêt
  Future<bool> updateInterestRate(String loanId, double newRate) async {
    try {
      print(
        '🔄 Début modification taux - Prêt: $loanId, Nouveau taux: $newRate%',
      );

      final loanDoc = await _firestore.collection('loans').doc(loanId).get();
      if (!loanDoc.exists) {
        throw Exception('Prêt non trouvé');
      }

      final loan = LoanModel.fromJson(loanDoc.data()!);
      print(
        '📋 Prêt trouvé - Statut: ${loan.statut}, Ancien taux: ${loan.tauxAnnuel}%',
      );

      // Recalcul des montants avec le nouveau taux
      final nouvelleMensualite = LoanCalculationService.calculateMensualite(
        loan.montant,
        newRate,
        loan.dureeMois,
      );

      // Utiliser le calcul exact des intérêts
      final nouveauCoutTotal =
          LoanCalculationService.calculateInteretsTotauxExacts(
            loan.montant,
            newRate,
          );

      print(
        '💰 Nouveaux calculs - Mensualité: $nouvelleMensualite€, Coût intérêts: $nouveauCoutTotal€',
      );

      // Mise à jour du prêt
      print('💾 Mise à jour du prêt en base...');
      await _firestore.collection('loans').doc(loanId).update({
        'tauxAnnuel': newRate,
        'mensualite': nouvelleMensualite,
        'coutTotalEstime': nouveauCoutTotal,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Si le prêt a déjà un échéancier, le recalculer
      print(
        '🔍 Vérification du statut pour échéancier - Statut: ${loan.statut}',
      );
      if (loan.statut == LoanStatus.enCours ||
          loan.statut == LoanStatus.decaissementEffectue ||
          loan.statut == LoanStatus.enRetard ||
          loan.statut == LoanStatus.approuve ||
          loan.statut == LoanStatus.solde) {
        print('✅ Régénération de l\'échéancier...');
        await _regeneratePaymentSchedule(loanId, loan, newRate);
      } else {
        print('⚠️  Pas de régénération d\'échéancier - Statut: ${loan.statut}');
      }

      // Notification à l'emprunteur du changement de taux
      await _sendRateChangeNotification(loan, newRate, nouvelleMensualite);

      print('✅ Modification du taux terminée avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la modification du taux: $e');
      return false;
    }
  }

  /// Régénérer l'échéancier avec le nouveau taux
  Future<void> _regeneratePaymentSchedule(
    String loanId,
    LoanModel loan,
    double newRate,
  ) async {
    try {
      print('🗑️ Suppression des échéances non payées...');
      // Supprimer l'ancien échéancier (seulement les échéances non payées)
      final scheduleQuery = await _firestore
          .collection('schedules')
          .where('loanId', isEqualTo: loanId)
          .where('isPaid', isEqualTo: false)
          .get();

      print('📊 Échéances trouvées à supprimer: ${scheduleQuery.docs.length}');
      for (final doc in scheduleQuery.docs) {
        print('🗑️ Suppression échéance: ${doc.id}');
        await doc.reference.delete();
      }

      // Recréer l'échéancier avec le nouveau taux
      final nouvelleMensualite = LoanCalculationService.calculateMensualite(
        loan.montant,
        newRate,
        loan.dureeMois,
      );

      // Créer un modèle de prêt mis à jour pour la génération de l'échéancier
      final updatedLoan = loan.copyWith(
        tauxAnnuel: newRate,
        mensualite: nouvelleMensualite,
      );

      print('📅 Génération du nouvel échéancier...');
      await _generateSchedule(updatedLoan);
      print('✅ Échéancier régénéré avec succès');
    } catch (e) {
      print('❌ Erreur lors de la régénération de l\'échéancier: $e');
    }
  }

  /// Envoyer une notification de changement de taux
  Future<void> _sendRateChangeNotification(
    LoanModel loan,
    double newRate,
    double newMensualite,
  ) async {
    try {
      // Notification push dans l'app
      await AppNotificationService.createNotification(
        userId: loan.userId,
        title: 'Taux d\'intérêt modifié',
        body:
            'Le taux de votre prêt de ${loan.montant.toStringAsFixed(0)}€ a été modifié à ${newRate.toStringAsFixed(2)}%. Nouvelle mensualité: ${newMensualite.toStringAsFixed(2)}€.',
        type: NotificationType.rateChange,
        data: {
          'loanId': loan.id,
          'oldRate': loan.tauxAnnuel,
          'newRate': newRate,
          'newMensualite': newMensualite,
        },
      );

      // ✨ NOUVEAU : Envoi d'email de notification
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
            print('📧 Envoi d\'email de modification de taux à: $userEmail');

            // Utiliser le calcul exact des intérêts
            final nouveauCoutTotal =
                LoanCalculationService.calculateInteretsTotauxExacts(
                  loan.montant,
                  newRate,
                );

            await EmailService.sendLoanNotificationEmail(
              to: userEmail,
              userName: userName,
              type: LoanEmailType.rateChanged,
              loanData: {
                'loanId': loan.id,
                'oldRate': loan.tauxAnnuel.toStringAsFixed(1),
                'newRate': newRate.toStringAsFixed(1),
                'oldMonthlyPayment': loan.mensualite.toStringAsFixed(0),
                'newMonthlyPayment': newMensualite.toStringAsFixed(0),
                'newTotalCost': (loan.montant + nouveauCoutTotal)
                    .toStringAsFixed(0),
              },
            );
            print('✅ Email de modification de taux envoyé avec succès');
          } else {
            print('⚠️ Email utilisateur non trouvé pour l\'envoi d\'email');
          }
        }
      } catch (emailError) {
        print('❌ Erreur lors de l\'envoi d\'email: $emailError');
        // Ne pas faire échouer la notification si l'email échoue
      }
    } catch (e) {
      print(
        '❌ Erreur lors de l\'envoi de la notification de changement de taux: $e',
      );
    }
  }

  /// Créer une nouvelle demande de prêt
  Future<LoanModel> createLoanRequest({
    required String userId,
    required String nomEmprunteur,
    required String ribEmprunteur,
    required double montant,
    required int dureeMois,
    // required String objetPret, // SUPPRIMÉ
    required DateTime dateSouhaitee,
  }) async {
    try {
      // Vérification de la durée maximale
      if (!LoanCalculationService.isDureeValide(dureeMois)) {
        throw Exception('Durée de remboursement invalide. Maximum 12 mois.');
      }

      // Récupérer le niveau de confiance du client
      double? niveauConfiance;
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          niveauConfiance = userData['niveauConfiance']?.toDouble();
          print(
            '🔍 [DEBUG] Niveau de confiance récupéré: $niveauConfiance pour user: $userId',
          );
        } else {
          print('⚠️ [DEBUG] Utilisateur non trouvé: $userId');
        }
      } catch (e) {
        print('⚠️ Impossible de récupérer le niveau de confiance: $e');
        // Continue sans niveau de confiance (taux normal)
      }

      // Calculs automatiques avec prise en compte du niveau de confiance
      final tauxBase = LoanCalculationService.calculateTauxSelonDuree(
        dureeMois,
      );
      final tauxAnnuel = LoanCalculationService.calculateTauxWithRisk(
        montant,
        dureeMois,
        niveauConfiance,
      );

      print(
        '🔍 [DEBUG] Calcul taux - Base: $tauxBase%, Avec risque: $tauxAnnuel%, Niveau confiance: $niveauConfiance',
      );

      // Valeurs par défaut pour compatibilité avec le modèle existant
      const tauxBaseLegacy = 0.0; // Non utilisé avec les nouvelles règles
      const coefficientDuree = 1.0; // Non utilisé avec les nouvelles règles
      final mensualite = LoanCalculationService.calculateMensualite(
        montant,
        tauxAnnuel,
        dureeMois,
      );
      // Utiliser le calcul exact des intérêts au lieu du calcul basé sur la mensualité arrondie
      final coutTotal = LoanCalculationService.calculateInteretsTotauxExacts(
        montant,
        tauxAnnuel,
      );

      // Calcul de la date de premier remboursement selon les nouvelles règles
      final datePremierRemboursement =
          LoanCalculationService.calculateDatePremierRemboursement(
            dateSouhaitee,
          );

      final loan = LoanModel(
        id: _uuid.v4(),
        userId: userId,
        nomEmprunteur: nomEmprunteur,
        ribEmprunteur: ribEmprunteur,
        montant: montant,
        dureeMois: dureeMois,
        tauxBase: tauxBaseLegacy,
        coefficientDuree: coefficientDuree,
        tauxAnnuel: tauxAnnuel,
        mensualite: mensualite,
        coutTotalEstime: coutTotal,
        // objetPret: objetPret, // SUPPRIMÉ
        dateSouhaitee: dateSouhaitee,
        datePremierRemboursement: datePremierRemboursement,
        statut: LoanStatus.soumis,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('loans').doc(loan.id).set(loan.toJson());

      // Envoyer notifications de demande créée
      try {
        // Récupérer les données utilisateur pour l'email
        final userDoc = await _firestore.collection('users').doc(userId).get();
        String userEmail = '';
        String userName = nomEmprunteur;

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userEmail = userData['email'] ?? '';
          userName = '${userData['prenom']} ${userData['nom']}';
        }

        // Notification in-app
        await AppNotificationService.notifyLoanRequested(
          userId: userId,
          userEmail: userEmail,
          userName: userName,
          loanId: loan.id,
          amount: montant,
          duration: dureeMois,
          rate: tauxAnnuel,
        );

        // 📧 Envoi d'email de confirmation
        if (userEmail.isNotEmpty) {
          await EmailService.sendLoanNotificationEmail(
            to: userEmail,
            userName: userName,
            type: LoanEmailType.loanRequested,
            loanData: {
              'amount': montant.toStringAsFixed(0),
              'duration': dureeMois.toString(),
              'rate': tauxAnnuel.toStringAsFixed(2),
              'loanId': loan.id,
              'submittedDate': EmailServiceExtensions.formatDate(
                DateTime.now(),
              ),
            },
          );
        }
      } catch (e) {
        print('Erreur envoi notification: $e');
        // Ne pas faire échouer la création du prêt si la notification échoue
      }

      return loan;
    } catch (e) {
      throw Exception('Erreur lors de la création de la demande: $e');
    }
  }

  /// Récupérer tous les prêts d'un utilisateur
  Future<List<LoanModel>> getUserLoans(String userId) async {
    try {
      print('🔍 [DEBUG SERVICE] Query Firestore pour userId: $userId');
      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .where('userId', isEqualTo: userId)
          .get();

      print(
        '🔍 [DEBUG SERVICE] Snapshot reçu: ${snapshot.docs.length} documents',
      );

      final loans = snapshot.docs.map((doc) {
        print('🔍 [DEBUG SERVICE] Document: ${doc.id} - Data: ${doc.data()}');
        return LoanModel.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      // Trier manuellement par createdAt (descendant)
      loans.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('🔍 [DEBUG SERVICE] Loans mappés et triés: ${loans.length} prêts');
      return loans;
    } catch (e) {
      print('❌ [ERROR SERVICE] Erreur: $e');
      throw Exception('Erreur lors de la récupération des prêts: $e');
    }
  }

  /// Récupérer tous les prêts (pour admin)
  Future<List<LoanModel>> getAllLoans({LoanStatus? status}) async {
    try {
      Query query = _firestore.collection('loans');

      if (status != null) {
        query = query.where('statut', isEqualTo: status.name);
      }

      final QuerySnapshot snapshot = await query
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => LoanModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des prêts: $e');
    }
  }

  /// Approuver un prêt (admin)
  Future<void> approveLoan(String loanId, String adminId) async {
    try {
      final loan = await getLoanById(loanId);
      if (loan == null) throw Exception('Prêt non trouvé');

      final updatedLoan = loan.copyWith(
        statut: LoanStatus.approuve,
        approvedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('loans')
          .doc(loanId)
          .update(updatedLoan.toJson());

      // Générer l'échéancier
      await _generateSchedule(loan);

      // 🔔 ENVOYER NOTIFICATION D'APPROBATION
      await _sendApprovalNotification(loan);

      // Enregistrer l'action admin
      await _logAdminAction(adminId, 'APPROVE_LOAN', loanId);
    } catch (e) {
      throw Exception('Erreur lors de l\'approbation: $e');
    }
  }

  /// Refuser un prêt (admin)
  Future<void> rejectLoan(String loanId, String adminId, String reason) async {
    try {
      final loan = await getLoanById(loanId);
      if (loan == null) throw Exception('Prêt non trouvé');

      final updatedLoan = loan.copyWith(
        statut: LoanStatus.refuse,
        noteAdmin: reason,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('loans')
          .doc(loanId)
          .update(updatedLoan.toJson());

      // 🔔 ENVOYER NOTIFICATION DE REJET
      await _sendRejectionNotification(loan, reason);

      // Enregistrer l'action admin
      await _logAdminAction(adminId, 'REJECT_LOAN', loanId);
    } catch (e) {
      throw Exception('Erreur lors du refus: $e');
    }
  }

  /// Marquer le décaissement comme effectué (admin)
  Future<void> markDisbursed(
    String loanId,
    String adminId,
    String reference,
  ) async {
    try {
      final loan = await getLoanById(loanId);
      if (loan == null) throw Exception('Prêt non trouvé');

      final updatedLoan = loan.copyWith(
        statut: LoanStatus.enCours,
        disbursedAt: DateTime.now(),
        referenceDecaissement: reference,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('loans')
          .doc(loanId)
          .update(updatedLoan.toJson());

      // 🔔 ENVOYER NOTIFICATION DE DÉCAISSEMENT
      await _sendDisbursementNotification(updatedLoan);

      // Enregistrer l'action admin
      await _logAdminAction(adminId, 'MARK_DISBURSED', loanId);
    } catch (e) {
      throw Exception('Erreur lors du marquage du décaissement: $e');
    }
  }

  /// Récupérer un prêt par ID
  Future<LoanModel?> getLoanById(String loanId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('loans')
          .doc(loanId)
          .get();

      if (doc.exists) {
        return LoanModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors de la récupération du prêt: $e');
    }
  }

  /// Récupérer l'échéancier d'un prêt
  Future<List<ScheduleItemModel>> getLoanSchedule(String loanId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('schedules')
          .where('loanId', isEqualTo: loanId)
          .orderBy('numero')
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                ScheduleItemModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération de l\'échéancier: $e');
    }
  }

  /// Marquer un paiement comme effectué (admin)
  Future<void> markPaymentReceived({
    required String scheduleItemId,
    required String adminId,
    required double amount,
    String? note,
  }) async {
    try {
      print('🔍 [LOAN_SERVICE] Marquage paiement pour: $scheduleItemId');

      // Extraire le loanId et le numéro d'échéance du scheduleItemId (format: loanId_numeroEcheance)
      final parts = scheduleItemId.split('_');
      final loanId = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('_')
          : scheduleItemId;
      final numero = parts.length > 1 ? int.tryParse(parts.last) : null;

      // D'abord, chercher le VRAI document (celui avec loanId dans les données)
      // car les schedules peuvent avoir des IDs auto-générés
      bool updated = false;

      if (numero != null) {
        print(
          '🔍 [LOAN_SERVICE] Recherche schedule avec loanId=$loanId et numero=$numero',
        );
        final querySnapshot = await _firestore
            .collection('schedules')
            .where('loanId', isEqualTo: loanId)
            .where('numero', isEqualTo: numero)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final realDoc = querySnapshot.docs.first;
          print(
            '✅ [LOAN_SERVICE] Vrai document trouvé (${realDoc.id}), mise à jour...',
          );
          await realDoc.reference.update({
            'isPaid': true,
            'paidAt': FieldValue.serverTimestamp(),
            'paidAmount': amount,
            'noteAdmin': note,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updated = true;
        }
      }

      // Fallback : chercher par ID direct (ancien comportement)
      if (!updated) {
        final docRef = _firestore.collection('schedules').doc(scheduleItemId);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          print(
            '✅ [LOAN_SERVICE] Document trouvé par ID direct, mise à jour...',
          );
          await docRef.update({
            'isPaid': true,
            'paidAt': FieldValue.serverTimestamp(),
            'paidAmount': amount,
            'noteAdmin': note,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updated = true;
        }
      }

      if (!updated) {
        print('⚠️ [LOAN_SERVICE] Aucun document trouvé pour $scheduleItemId');
        throw Exception('Échéance non trouvée: $scheduleItemId');
      }

      print('✅ [LOAN_SERVICE] Paiement marqué avec succès');

      // 🔔 ENVOYER NOTIFICATION DE PAIEMENT REÇU
      await _sendPaymentReceivedNotification(loanId, amount, scheduleItemId);

      // Enregistrer l'action admin
      await _logAdminAction(adminId, 'MARK_PAYMENT', scheduleItemId);

      print('✅ [LOAN_SERVICE] Action admin enregistrée');
    } catch (e) {
      print('❌ [LOAN_SERVICE] Erreur marquage: $e');
      throw Exception('Erreur lors du marquage du paiement: $e');
    }
  }

  /// Générer l'échéancier pour un prêt approuvé
  Future<void> _generateSchedule(LoanModel loan) async {
    print(
      '📅 Génération échéancier - Prêt: ${loan.id}, Taux: ${loan.tauxAnnuel}%, Mensualité: ${loan.mensualite}€',
    );

    final schedule = LoanCalculationService.generateSchedule(
      loanId: loan.id,
      capital: loan.montant,
      tauxAnnuel: loan.tauxAnnuel,
      dureeMois: loan.dureeMois,
      mensualite: loan.mensualite,
      datePremierePaiement: loan.dateSouhaitee,
    );

    print('📊 Échéancier généré - ${schedule.length} échéances');

    final batch = _firestore.batch();
    for (final item in schedule) {
      print(
        '💾 Sauvegarde échéance ${item.numero}: ${item.total}€ (capital: ${item.principal}€, intérêts: ${item.interet}€)',
      );
      batch.set(_firestore.collection('schedules').doc(item.id), item.toJson());
    }
    await batch.commit();
    print('✅ Échéancier sauvegardé en base');
  }

  /// Annuler un prêt accepté (emprunteur ou admin)
  Future<void> cancelLoan({
    required String loanId,
    required String userId,
    String? reason,
    bool isAdmin = false,
  }) async {
    try {
      final loan = await getLoanById(loanId);
      if (loan == null) throw Exception('Prêt non trouvé');

      // Vérification selon le type d'utilisateur
      bool canCancel = isAdmin
          ? loan.canBeCancelledByAdmin
          : loan.canBeCancelledByBorrower;

      if (!canCancel) {
        throw Exception('Ce prêt ne peut pas être annulé dans son état actuel');
      }

      final updatedLoan = loan.copyWith(
        statut: LoanStatus.annule,
        noteAdmin: reason ?? 'Annulé par l\'emprunteur',
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('loans')
          .doc(loanId)
          .update(updatedLoan.toJson());

      // Envoyer notification d'annulation
      await _sendCancellationNotification(loan, reason);

      // Enregistrer l'action
      await _logAdminAction(userId, 'CANCEL_LOAN', loanId);
    } catch (e) {
      throw Exception('Erreur lors de l\'annulation: $e');
    }
  }

  /// Clôturer automatiquement les prêts soldés
  Future<void> autoCloseCompletedLoans() async {
    try {
      // Récupérer tous les prêts en cours
      final activeLoans = await getAllLoans(status: LoanStatus.enCours);

      for (final loan in activeLoans) {
        final isFullyPaid = await _checkIfLoanFullyPaid(loan.id);

        if (isFullyPaid) {
          // Clôturer le prêt
          final updatedLoan = loan.copyWith(
            statut: LoanStatus.ferme,
            updatedAt: DateTime.now(),
            noteAdmin: 'Clôturé automatiquement - Toutes les échéances payées',
          );

          await _firestore
              .collection('loans')
              .doc(loan.id)
              .update(updatedLoan.toJson());

          // Envoyer notification de clôture
          await _sendCompletionNotification(loan);

          // Enregistrer l'action
          await _logAdminAction('SYSTEM', 'AUTO_CLOSE_LOAN', loan.id);
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de la clôture automatique: $e');
    }
  }

  /// Vérifier si toutes les échéances d'un prêt sont payées
  Future<bool> _checkIfLoanFullyPaid(String loanId) async {
    try {
      final scheduleSnapshot = await _firestore
          .collection('schedules')
          .where('loanId', isEqualTo: loanId)
          .get();

      if (scheduleSnapshot.docs.isEmpty) return false;

      // Vérifier que toutes les échéances sont payées
      for (final doc in scheduleSnapshot.docs) {
        final data = doc.data();
        final isPaid = data['isPaid'] ?? false;
        if (!isPaid) return false;
      }

      return true;
    } catch (e) {
      print('Erreur vérification paiement complet: $e');
      return false;
    }
  }

  /// Envoyer notification d'approbation
  Future<void> _sendApprovalNotification(LoanModel loan) async {
    try {
      // Récupérer les données utilisateur
      final userDoc = await _firestore
          .collection('users')
          .doc(loan.userId)
          .get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      final userName = '${userData['prenom']} ${userData['nom']}';

      // Notification in-app
      await AppNotificationService.notifyLoanApproved(
        userId: loan.userId,
        userEmail: userEmail,
        userName: userName,
        loanId: loan.id,
        amount: loan.montant,
        duration: loan.dureeMois,
        rate: loan.tauxAnnuel,
        firstPaymentDate: loan.datePremierRemboursement.toIso8601String(),
      );

      // 📧 Envoi d'email d'approbation
      if (userEmail.isNotEmpty) {
        await EmailService.sendLoanNotificationEmail(
          to: userEmail,
          userName: userName,
          type: LoanEmailType.loanApproved,
          loanData: {
            'amount': loan.montant.toStringAsFixed(0),
            'duration': loan.dureeMois.toString(),
            'rate': loan.tauxAnnuel.toStringAsFixed(2),
            'loanId': loan.id,
            'approvedDate': EmailServiceExtensions.formatDate(
              loan.approvedAt ?? DateTime.now(),
            ),
            'firstPaymentDate': EmailServiceExtensions.formatDate(
              loan.datePremierRemboursement,
            ),
            'monthlyPayment': loan.mensualite.toStringAsFixed(2),
          },
        );
      }
    } catch (e) {
      print('Erreur envoi notification approbation: $e');
    }
  }

  /// Envoyer notification de rejet
  Future<void> _sendRejectionNotification(LoanModel loan, String reason) async {
    try {
      // Récupérer les données utilisateur
      final userDoc = await _firestore
          .collection('users')
          .doc(loan.userId)
          .get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      final userName = '${userData['prenom']} ${userData['nom']}';

      // Notification in-app
      await AppNotificationService.notifyLoanRejected(
        userId: loan.userId,
        userEmail: userEmail,
        userName: userName,
        loanId: loan.id,
        reason: reason,
      );

      // 📧 Envoi d'email de rejet
      if (userEmail.isNotEmpty) {
        await EmailService.sendLoanNotificationEmail(
          to: userEmail,
          userName: userName,
          type: LoanEmailType.loanRejected,
          loanData: {
            'amount': loan.montant.toStringAsFixed(0),
            'duration': loan.dureeMois.toString(),
            'loanId': loan.id,
            'rejectedDate': EmailServiceExtensions.formatDate(DateTime.now()),
            'reason': reason,
          },
        );
      }
    } catch (e) {
      print('Erreur envoi notification rejet: $e');
    }
  }

  /// Envoyer notification de décaissement
  Future<void> _sendDisbursementNotification(LoanModel loan) async {
    try {
      // Récupérer les données utilisateur
      final userDoc = await _firestore
          .collection('users')
          .doc(loan.userId)
          .get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? '';
      final userName = '${userData['prenom']} ${userData['nom']}';

      // Notification in-app
      await AppNotificationService.createNotification(
        userId: loan.userId,
        title: 'Décaissement effectué',
        body:
            'Votre prêt de ${loan.montant.toStringAsFixed(0)}€ a été décaissé. Vos remboursements commencent maintenant.',
        type: NotificationType.loanApproved, // Réutiliser le type approbation
        data: {
          'loanId': loan.id,
          'amount': loan.montant,
          'reference': loan.referenceDecaissement ?? '',
          'disbursedAt': loan.disbursedAt?.toIso8601String() ?? '',
        },
      );

      // 📧 Envoi d'email de décaissement
      if (userEmail.isNotEmpty) {
        await EmailService.sendLoanNotificationEmail(
          to: userEmail,
          userName: userName,
          type: LoanEmailType.loanDisbursed,
          loanData: {
            'amount': loan.montant.toStringAsFixed(0),
            'duration': loan.dureeMois.toString(),
            'loanId': loan.id,
            'disbursedDate': EmailServiceExtensions.formatDate(
              loan.disbursedAt ?? DateTime.now(),
            ),
            'reference': loan.referenceDecaissement ?? '',
            'firstPaymentDate': EmailServiceExtensions.formatDate(
              loan.datePremierRemboursement,
            ),
            'monthlyPayment': loan.mensualite.toStringAsFixed(2),
          },
        );
      }
    } catch (e) {
      print('Erreur envoi notification décaissement: $e');
    }
  }

  /// Envoyer notification de paiement reçu
  Future<void> _sendPaymentReceivedNotification(
    String loanId,
    double amount,
    String scheduleItemId,
  ) async {
    try {
      final loan = await getLoanById(loanId);
      if (loan == null) return;

      // Notification push dans l'app
      await AppNotificationService.createNotification(
        userId: loan.userId,
        title: 'Paiement reçu',
        body: 'Votre paiement de ${amount.toStringAsFixed(0)}€ a été confirmé.',
        type: NotificationType.paymentReceived,
        data: {
          'loanId': loan.id,
          'amount': amount,
          'receivedAt': DateTime.now().toIso8601String(),
        },
      );

      // ✨ NOUVEAU : Envoi d'email de confirmation
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
            print(
              '📧 Envoi d\'email de confirmation de paiement à: $userEmail',
            );

            // Extraire le numéro d'échéance du scheduleItemId
            final scheduleNumber = scheduleItemId.contains('_')
                ? scheduleItemId.split('_').last
                : '1';

            await EmailService.sendLoanNotificationEmail(
              to: userEmail,
              userName: userName,
              type: LoanEmailType.paymentReceived,
              loanData: {
                'amount': amount.toStringAsFixed(0),
                'paymentDate': DateTime.now().toIso8601String().split('T')[0],
                'scheduleNumber': scheduleNumber,
                'loanId': loan.id,
              },
            );
            print('✅ Email de confirmation de paiement envoyé avec succès');
          }
        }
      } catch (emailError) {
        print('❌ Erreur lors de l\'envoi d\'email: $emailError');
        // Ne pas faire échouer la notification si l'email échoue
      }
    } catch (e) {
      print('Erreur envoi notification paiement reçu: $e');
    }
  }

  /// Envoyer notification d'annulation
  Future<void> _sendCancellationNotification(
    LoanModel loan,
    String? reason,
  ) async {
    try {
      await AppNotificationService.createNotification(
        userId: loan.userId,
        title: 'Prêt annulé',
        body: 'Votre prêt de ${loan.montant.toStringAsFixed(0)}€ a été annulé.',
        type: NotificationType.loanRejected, // Réutiliser le type rejet
        data: {
          'loanId': loan.id,
          'reason': reason ?? 'Annulé',
          'amount': loan.montant,
        },
      );
    } catch (e) {
      print('Erreur envoi notification annulation: $e');
    }
  }

  /// Envoyer notification de clôture
  Future<void> _sendCompletionNotification(LoanModel loan) async {
    try {
      await AppNotificationService.createNotification(
        userId: loan.userId,
        title: 'Prêt clôturé',
        body:
            'Félicitations ! Votre prêt de ${loan.montant.toStringAsFixed(0)}€ est entièrement remboursé.',
        type: NotificationType.loanCompleted,
        data: {
          'loanId': loan.id,
          'amount': loan.montant,
          'completedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Erreur envoi notification clôture: $e');
    }
  }

  /// Enregistrer une action admin dans l'audit log
  Future<void> _logAdminAction(
    String adminId,
    String action,
    String entityId,
  ) async {
    await _firestore.collection('audit_logs').add({
      'adminId': adminId,
      'action': action,
      'entityId': entityId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
