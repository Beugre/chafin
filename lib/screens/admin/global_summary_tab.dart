import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/payment_reminder_service.dart';

/// Onglet Résumé Global — tableau de bord des prêts actifs et fermés
/// avec détail des échéances, montants remboursés, intérêts payés,
/// et boutons de rappel de paiement (standard / urgent).
class GlobalSummaryTab extends StatefulWidget {
  const GlobalSummaryTab({super.key});

  @override
  State<GlobalSummaryTab> createState() => _GlobalSummaryTabState();
}

class _GlobalSummaryTabState extends State<GlobalSummaryTab> {
  bool _isLoading = true;
  List<_LoanSummary> _summaries = [];
  String? _sendingReminderLoanId;
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // ⚡ 3 requêtes BULK au lieu de N requêtes séquentielles
      final results = await Future.wait([
        firestore.collection('loans').get(),
        firestore.collection('users').get(),
        firestore.collection('schedules').get(),
      ]);

      final loansSnap = results[0];
      final usersSnap = results[1];
      final schedulesSnap = results[2];

      // Indexer les utilisateurs par ID
      final Map<String, Map<String, dynamic>> usersById = {};
      for (final doc in usersSnap.docs) {
        usersById[doc.id] = doc.data() as Map<String, dynamic>;
      }

      // Indexer les échéances par loanId
      final Map<String, List<Map<String, dynamic>>> schedulesByLoan = {};
      for (final doc in schedulesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final loanId = data['loanId'] as String?;
        if (loanId != null) {
          schedulesByLoan.putIfAbsent(loanId, () => []);
          schedulesByLoan[loanId]!.add(data);
        }
      }

      final List<_LoanSummary> summaries = [];
      final now = DateTime.now();

      for (final loanDoc in loansSnap.docs) {
        final loan = loanDoc.data() as Map<String, dynamic>;
        final loanId = loanDoc.id;
        final statut = loan['statut'] as String? ?? '';

        // Ignorer les prêts annulés, refusés et brouillons
        if ([
          'annule',
          'refuse',
          'brouillon',
          'soumis',
          'enRevue',
        ].contains(statut)) {
          continue;
        }

        // Récupérer le nom depuis le cache mémoire
        String borrowerName = 'Inconnu';
        final userId = (loan['emprunteurId'] ?? loan['userId'] ?? '') as String;
        if (userId.isNotEmpty && usersById.containsKey(userId)) {
          final userData = usersById[userId]!;
          borrowerName =
              userData['nom'] as String? ??
              userData['displayName'] as String? ??
              'Inconnu';
        }

        // Récupérer les échéances depuis le cache mémoire
        final echeances = schedulesByLoan[loanId] ?? [];
        // Trier par numéro
        echeances.sort(
          (a, b) => ((a['numero'] as int?) ?? 0).compareTo(
            (b['numero'] as int?) ?? 0,
          ),
        );

        final totalEcheances = echeances.length;
        final payees = echeances.where((e) => e['isPaid'] == true).toList();
        final impayees = echeances.where((e) => e['isPaid'] != true).toList();

        // Calculs des montants
        double montantRembourse = 0;
        double interetsPaies = 0;
        double montantTotalDu = 0;
        double interetsTotaux = 0;

        for (final e in echeances) {
          montantTotalDu += (e['total'] as num?)?.toDouble() ?? 0;
          interetsTotaux += (e['interet'] as num?)?.toDouble() ?? 0;
        }

        for (final e in payees) {
          montantRembourse += (e['total'] as num?)?.toDouble() ?? 0;
          interetsPaies += (e['interet'] as num?)?.toDouble() ?? 0;
        }

        // Échéances en retard
        final enRetard = impayees.where((e) {
          final dueDate = (e['dueDate'] as Timestamp?)?.toDate();
          return dueDate != null && dueDate.isBefore(now);
        }).toList();

        int maxJoursRetard = 0;
        for (final e in enRetard) {
          final dueDate = (e['dueDate'] as Timestamp?)?.toDate();
          if (dueDate != null) {
            final jours = now.difference(dueDate).inDays;
            if (jours > maxJoursRetard) maxJoursRetard = jours;
          }
        }

        // Prochaine échéance impayée future
        DateTime? prochaineDate;
        int? prochaineNumero;
        for (final e in impayees) {
          final dueDate = (e['dueDate'] as Timestamp?)?.toDate();
          if (dueDate != null && !dueDate.isBefore(now)) {
            prochaineDate = dueDate;
            prochaineNumero = e['numero'] as int?;
            break;
          }
        }

        final montant = (loan['montant'] as num?)?.toDouble() ?? 0;

        summaries.add(
          _LoanSummary(
            loanId: loanId,
            borrowerName: borrowerName,
            montant: montant,
            statut: statut,
            totalEcheances: totalEcheances,
            echeancesPayees: payees.length,
            echeancesEnRetard: enRetard.length,
            maxJoursRetard: maxJoursRetard,
            montantRembourse: montantRembourse,
            montantTotalDu: montantTotalDu,
            interetsPaies: interetsPaies,
            interetsTotaux: interetsTotaux,
            prochaineDate: prochaineDate,
            prochaineNumero: prochaineNumero,
          ),
        );
      }

      // Tri : en retard d'abord (par jours décroissants), puis à jour, puis fermés
      summaries.sort((a, b) {
        if (a.statut == 'ferme' && b.statut != 'ferme') return 1;
        if (a.statut != 'ferme' && b.statut == 'ferme') return -1;
        if (a.echeancesEnRetard > 0 && b.echeancesEnRetard == 0) return -1;
        if (a.echeancesEnRetard == 0 && b.echeancesEnRetard > 0) return 1;
        return b.maxJoursRetard - a.maxJoursRetard;
      });

      setState(() {
        _summaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendReminder(String loanId, bool isUrgent) async {
    setState(() => _sendingReminderLoanId = loanId);
    try {
      final success = await PaymentReminderService.sendManualReminder(
        loanId: loanId,
        type: isUrgent ? ReminderType.urgent : ReminderType.standard,
        customMessage: isUrgent
            ? 'Rappel urgent de paiement - Votre échéance est en retard. Merci de régulariser votre situation au plus vite.'
            : 'Rappel de paiement - N\'oubliez pas votre prochaine échéance.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Rappel ${isUrgent ? "urgent" : "standard"} envoyé'
                  : '❌ Erreur lors de l\'envoi du rappel',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
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
      setState(() => _sendingReminderLoanId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Chargement du résumé global...'),
          ],
        ),
      );
    }

    // Calculs globaux
    final enRetardCount = _summaries
        .where((s) => s.echeancesEnRetard > 0 && s.statut != 'ferme')
        .length;
    final aJourCount = _summaries
        .where(
          (s) =>
              s.echeancesEnRetard == 0 &&
              s.statut != 'ferme' &&
              s.statut != 'solde',
        )
        .length;
    final fermeCount = _summaries
        .where((s) => s.statut == 'ferme' || s.statut == 'solde')
        .length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête résumé
            _buildHeaderCards(enRetardCount, aJourCount, fermeCount),
            const SizedBox(height: 16),

            // Section Prêts en retard
            if (_summaries.any(
              (s) => s.echeancesEnRetard > 0 && s.statut != 'ferme',
            )) ...[
              _buildSectionTitle('🔴 Prêts EN RETARD', Colors.red),
              const SizedBox(height: 8),
              ..._summaries
                  .where((s) => s.echeancesEnRetard > 0 && s.statut != 'ferme')
                  .map((s) => _buildLoanSummaryCard(s)),
              const SizedBox(height: 20),
            ],

            // Section Prêts à jour
            if (_summaries.any(
              (s) =>
                  s.echeancesEnRetard == 0 &&
                  s.statut != 'ferme' &&
                  s.statut != 'solde',
            )) ...[
              _buildSectionTitle('🟢 Prêts À JOUR', Colors.green),
              const SizedBox(height: 8),
              ..._summaries
                  .where(
                    (s) =>
                        s.echeancesEnRetard == 0 &&
                        s.statut != 'ferme' &&
                        s.statut != 'solde',
                  )
                  .map((s) => _buildLoanSummaryCard(s)),
              const SizedBox(height: 20),
            ],

            // Section Prêts fermés
            if (_summaries.any(
              (s) => s.statut == 'ferme' || s.statut == 'solde',
            )) ...[
              _buildSectionTitle('⚪ Prêts FERMÉS (tout payé)', Colors.grey),
              const SizedBox(height: 8),
              ..._summaries
                  .where((s) => s.statut == 'ferme' || s.statut == 'solde')
                  .map((s) => _buildLoanSummaryCard(s)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCards(int enRetard, int aJour, int ferme) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard('En retard', '$enRetard', Colors.red),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStatCard('À jour', '$aJour', Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStatCard('Fermés', '$ferme', Colors.grey)),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildLoanSummaryCard(_LoanSummary summary) {
    final isOverdue = summary.echeancesEnRetard > 0;
    final isClosed = summary.statut == 'ferme' || summary.statut == 'solde';
    final isSending = _sendingReminderLoanId == summary.loanId;

    Color borderColor;
    if (isClosed) {
      borderColor = Colors.grey.shade300;
    } else if (isOverdue) {
      borderColor = Colors.red.shade300;
    } else {
      borderColor = Colors.green.shade300;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : Nom + Montant + Badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.borrowerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_currencyFormat.format(summary.montant)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(summary),
              ],
            ),
            const SizedBox(height: 12),

            // Ligne 2 : Tableau des données
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _buildDataRow(
                    '📋 Échéances payées',
                    '${summary.echeancesPayees}/${summary.totalEcheances}',
                    null,
                  ),
                  const Divider(height: 12),
                  _buildDataRow(
                    '💰 Remboursé',
                    '${summary.montantRembourse.toStringAsFixed(2)}€ / ${summary.montantTotalDu.toStringAsFixed(2)}€',
                    summary.montantRembourse >= summary.montantTotalDu
                        ? Colors.green
                        : null,
                  ),
                  const Divider(height: 12),
                  _buildDataRow(
                    '📊 Intérêts payés',
                    '${summary.interetsPaies.toStringAsFixed(2)}€ / ${summary.interetsTotaux.toStringAsFixed(2)}€',
                    null,
                  ),
                  if (isOverdue) ...[
                    const Divider(height: 12),
                    _buildDataRow(
                      '⏰ Retard max',
                      '${summary.maxJoursRetard} jour(s)',
                      Colors.red,
                    ),
                  ],
                  if (summary.prochaineDate != null) ...[
                    const Divider(height: 12),
                    _buildDataRow(
                      '➡️ Prochaine',
                      '#${summary.prochaineNumero} le ${DateFormat('dd/MM/yyyy').format(summary.prochaineDate!)}',
                      Colors.blue,
                    ),
                  ],
                ],
              ),
            ),

            // Boutons de rappel (sauf pour prêts fermés)
            if (!isClosed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSending
                          ? null
                          : () => _sendReminder(summary.loanId, false),
                      icon: isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.email_outlined, size: 16),
                      label: const Text(
                        'Rappel standard',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo,
                        side: const BorderSide(color: Colors.indigo),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isSending
                          ? null
                          : () => _sendReminder(summary.loanId, true),
                      icon: isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.warning_amber_outlined, size: 16),
                      label: const Text(
                        'Rappel urgent',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOverdue ? Colors.red : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(_LoanSummary summary) {
    final isClosed = summary.statut == 'ferme' || summary.statut == 'solde';
    final isOverdue = summary.echeancesEnRetard > 0;

    Color bgColor;
    Color textColor;
    String label;

    if (isClosed) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
      label = '✅ Fermé';
    } else if (isOverdue) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
      label = '🔴 ${summary.echeancesEnRetard} en retard';
    } else {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade700;
      label = '🟢 À jour';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Modèle interne pour stocker le résumé d'un prêt
class _LoanSummary {
  final String loanId;
  final String borrowerName;
  final double montant;
  final String statut;
  final int totalEcheances;
  final int echeancesPayees;
  final int echeancesEnRetard;
  final int maxJoursRetard;
  final double montantRembourse;
  final double montantTotalDu;
  final double interetsPaies;
  final double interetsTotaux;
  final DateTime? prochaineDate;
  final int? prochaineNumero;

  _LoanSummary({
    required this.loanId,
    required this.borrowerName,
    required this.montant,
    required this.statut,
    required this.totalEcheances,
    required this.echeancesPayees,
    required this.echeancesEnRetard,
    required this.maxJoursRetard,
    required this.montantRembourse,
    required this.montantTotalDu,
    required this.interetsPaies,
    required this.interetsTotaux,
    this.prochaineDate,
    this.prochaineNumero,
  });
}
