import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment_schedule_model.dart';

class PaymentScheduleScreen extends StatelessWidget {
  final PaymentSchedule paymentSchedule;

  const PaymentScheduleScreen({super.key, required this.paymentSchedule});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Échéancier détaillé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showScheduleInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Résumé en haut
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Résumé de l\'échéancier',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Capital',
                          '${paymentSchedule.totalCapital.toStringAsFixed(2)} €',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Intérêts',
                          '${paymentSchedule.totalInterets.toStringAsFixed(2)} €',
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Total',
                          '${paymentSchedule.totalMontant.toStringAsFixed(2)} €',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // En-tête du tableau
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'N°',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Capital',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Intérêts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Reste',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Liste des échéances
          Expanded(
            child: ListView.builder(
              itemCount: paymentSchedule.echeances.length,
              itemBuilder: (context, index) {
                final echeance = paymentSchedule.echeances[index];
                final isEven = index % 2 == 0;

                return Container(
                  color: isEven
                      ? null
                      : Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: _getStatusColor(echeance.statut),
                          child: Text(
                            '${echeance.numeroEcheance}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'dd/MM/yy',
                              ).format(echeance.dateEcheance),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (echeance.isOverdue && !echeance.isPaid)
                              const Text(
                                'En retard',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${echeance.montantCapital.toStringAsFixed(0)}€',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${echeance.montantInterets.toStringAsFixed(0)}€',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${echeance.montantTotal.toStringAsFixed(0)}€',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${echeance.capitalRestantDu.toStringAsFixed(0)}€',
                          style: TextStyle(
                            fontSize: 13,
                            color: echeance.capitalRestantDu == 0
                                ? Colors.green
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Color _getStatusColor(PaymentStatus status) {
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

  void _showScheduleInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informations sur l\'échéancier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Nombre d\'échéances',
              '${paymentSchedule.echeances.length}',
            ),
            _buildInfoRow(
              'Montant total',
              '${paymentSchedule.totalMontant.toStringAsFixed(2)} €',
            ),
            _buildInfoRow(
              'Dont capital',
              '${paymentSchedule.totalCapital.toStringAsFixed(2)} €',
            ),
            _buildInfoRow(
              'Dont intérêts',
              '${paymentSchedule.totalInterets.toStringAsFixed(2)} €',
            ),
            const SizedBox(height: 12),
            const Text(
              'Légende des couleurs :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildLegendRow('À venir', Colors.grey),
            _buildLegendRow('Échue', Colors.orange),
            _buildLegendRow('Payée', Colors.green),
            _buildLegendRow('En retard', Colors.red),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
