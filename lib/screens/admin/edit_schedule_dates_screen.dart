import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/loan_model.dart';
import '../../models/schedule_item_model.dart';
import '../../services/admin_service.dart';

/// Écran pour modifier la date de première échéance d'un prêt
class EditScheduleDatesScreen extends StatefulWidget {
  final LoanModel loan;

  const EditScheduleDatesScreen({Key? key, required this.loan})
    : super(key: key);

  @override
  State<EditScheduleDatesScreen> createState() =>
      _EditScheduleDatesScreenState();
}

class _EditScheduleDatesScreenState extends State<EditScheduleDatesScreen> {
  final AdminService _adminService = AdminService();
  DateTime? _newStartDate;
  List<ScheduleItemModel> _schedules = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      setState(() => _isLoading = true);

      final allSchedules = await _adminService.getAllSchedules();
      final loanSchedules = allSchedules
          .where((s) => s.loanId == widget.loan.id)
          .toList();

      loanSchedules.sort((a, b) => a.numero.compareTo(b.numero));

      setState(() {
        _schedules = loanSchedules;
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

  Future<void> _generateSchedules() async {
    try {
      // Utiliser la date de premier remboursement ou date actuelle + 5 jours
      final startDate =
          widget.loan.datePremierRemboursement ??
          DateTime.now().add(const Duration(days: 5));

      // Calculer les intérêts totaux (formule TAUX SIMPLE)
      final interetsTotal =
          widget.loan.montant * (widget.loan.tauxAnnuel / 100);
      final montantTotal = widget.loan.montant + interetsTotal;
      final mensualite = montantTotal / widget.loan.dureeMois;

      // Générer les échéances
      for (int i = 0; i < widget.loan.dureeMois; i++) {
        final dueDate = DateTime(
          startDate.year,
          startDate.month + i,
          startDate.day,
        );

        final schedule = ScheduleItemModel(
          id: '', // Firestore générera l'ID
          loanId: widget.loan.id,
          numero: i + 1,
          dueDate: dueDate,
          principal: widget.loan.montant / widget.loan.dureeMois,
          interet: interetsTotal / widget.loan.dureeMois,
          total: mensualite,
          isPaid: false,
          createdAt: DateTime.now(),
        );
        await _adminService.addScheduleItem(schedule);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Échéancier généré (${widget.loan.dureeMois} mensualités)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectNewDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _schedules.isNotEmpty
          ? _schedules.first.dueDate
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D4FF),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _newStartDate = picked);
    }
  }

  List<DateTime> _calculateNewDates() {
    if (_newStartDate == null || _schedules.isEmpty) return [];

    final List<DateTime> newDates = [];
    for (int i = 0; i < _schedules.length; i++) {
      final newDate = DateTime(
        _newStartDate!.year,
        _newStartDate!.month + i,
        _newStartDate!.day,
      );
      newDates.add(newDate);
    }
    return newDates;
  }

  Future<void> _saveNewDates() async {
    if (_newStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une nouvelle date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      await _adminService.updateScheduleStartDate(
        loanId: widget.loan.id,
        newStartDate: _newStartDate!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dates d\'échéancier mises à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retourner avec succès
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Modifier les dates d\'échéancier'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLoanInfo(),
                  const SizedBox(height: 24),
                  _buildCurrentSchedule(),
                  const SizedBox(height: 24),
                  _buildDateSelector(),
                  if (_newStartDate != null) ...[
                    const SizedBox(height: 24),
                    _buildNewSchedulePreview(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLoanInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations du prêt',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Montant',
            '${widget.loan.montant.toStringAsFixed(0)}€',
          ),
          _buildInfoRow('Durée', '${widget.loan.dureeMois} mois'),
          _buildInfoRow(
            'Taux',
            '${widget.loan.tauxAnnuel.toStringAsFixed(2)}%',
          ),
          _buildInfoRow(
            'Mensualité',
            '${widget.loan.mensualite.toStringAsFixed(2)}€',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSchedule() {
    if (_schedules.isEmpty) {
      return Card(
        color: const Color(0xFF1E293B),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Aucun échéancier trouvé',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Utilisez "Modifier le taux" pour générer un échéancier d\'abord',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Échéancier actuel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._schedules
              .take(3)
              .map(
                (schedule) => _buildScheduleRow(
                  schedule.numero,
                  schedule.dueDate,
                  schedule.total,
                  schedule.isPaid,
                ),
              ),
          if (_schedules.length > 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '... et ${_schedules.length - 3} autres échéances',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(
    int numero,
    DateTime date,
    double amount,
    bool isPaid,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isPaid
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '#$numero',
                style: TextStyle(
                  color: isPaid ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)}€',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isPaid) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nouvelle date de première échéance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectNewDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF00D4FF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _newStartDate == null
                          ? 'Sélectionner une date'
                          : DateFormat('dd/MM/yyyy').format(_newStartDate!),
                      style: TextStyle(
                        color: _newStartDate == null
                            ? Colors.white.withOpacity(0.5)
                            : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSchedulePreview() {
    final newDates = _calculateNewDates();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Aperçu des nouvelles dates',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...newDates.take(3).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final date = entry.value;
            return _buildNewScheduleRow(
              index + 1,
              date,
              _schedules[index].total,
            );
          }),
          if (newDates.length > 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '... et ${newDates.length - 3} autres échéances',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewScheduleRow(int numero, DateTime date, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '#$numero',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)}€',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, color: Colors.green, size: 16),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveNewDates,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          disabledBackgroundColor: Colors.green.withOpacity(0.5),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Appliquer les nouvelles dates',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
