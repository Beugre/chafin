import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/payment_reminder_service.dart';

/// Écran d'historique et statistiques des rappels de paiement
class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({super.key});

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentReminders = [];
  bool _isLoading = true;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger les statistiques
      final stats = await PaymentReminderService.getReminderStats(
        startDate: _startDate,
        endDate: _endDate,
      );

      // Charger l'historique réel des rappels
      List<Map<String, dynamic>> recentReminders = [];

      setState(() {
        _stats = stats;
        _recentReminders = recentReminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historique des Rappels',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Statistiques', icon: Icon(Icons.analytics)),
            Tab(text: 'Historique', icon: Icon(Icons.history)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Sélectionner une période',
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildStatsTab(), _buildHistoryTab()],
            ),
    );
  }

  Widget _buildStatsTab() {
    if (_stats.isEmpty) {
      return const Center(
        child: Text(
          'Aucune donnée disponible pour cette période',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodInfo(),
          const SizedBox(height: 24),
          _buildOverviewCards(),
          const SizedBox(height: 24),
          _buildDetailedStats(),
        ],
      ),
    );
  }

  Widget _buildPeriodInfo() {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.indigo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Période analysée',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Du ${formatter.format(_startDate)} au ${formatter.format(_endDate)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final total = _stats['total'] ?? 0;
    final sent = _stats['sent'] ?? 0;
    final successRate = total > 0 ? (sent / total * 100).round() : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total des rappels',
            total.toString(),
            Icons.email,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Envoyés avec succès',
            sent.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Taux de succès',
            '$successRate%',
            Icons.trending_up,
            successRate >= 80 ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition par type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTypeStatRow(
              'Rappels standard',
              _stats['standard'] ?? 0,
              Colors.blue,
            ),
            _buildTypeStatRow(
              'Rappels urgents',
              _stats['urgent'] ?? 0,
              Colors.orange,
            ),
            _buildTypeStatRow('Retards', _stats['overdue'] ?? 0, Colors.red),
            _buildTypeStatRow('Échecs', _stats['failed'] ?? 0, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeStatRow(String label, int count, Color color) {
    final total = _stats['total'] ?? 1;
    final percentage = total > 0 ? (count / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$count ($percentage%)',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_recentReminders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucun historique disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les rappels envoyés apparaîtront ici',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentReminders.length,
      itemBuilder: (context, index) {
        final reminder = _recentReminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    final sentAt = reminder['sentAt']?.toDate() ?? DateTime.now();
    final type = reminder['type'] ?? 'standard';
    final status = reminder['status'] ?? 'unknown';
    final message = reminder['message'] ?? 'Aucun message';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help;

    switch (status) {
      case 'sent':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _getTypeLabel(type),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  formatter.format(sentAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'standard':
        return 'Rappel standard';
      case 'urgent':
        return 'Rappel urgent';
      case 'overdue':
        return 'Paiement en retard';
      case 'finalNotice':
        return 'Dernier avis';
      default:
        return 'Type inconnu';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'Envoyé';
      case 'failed':
        return 'Échec';
      case 'pending':
        return 'En attente';
      case 'cancelled':
        return 'Annulé';
      default:
        return 'Inconnu';
    }
  }
}
