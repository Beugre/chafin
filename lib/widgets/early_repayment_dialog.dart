import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/loan_model.dart';
import '../services/early_repayment_service.dart';

class EarlyRepaymentDialog extends StatefulWidget {
  final LoanModel loan;
  final Function(double montantAnticipe, int nouvelleDuree)?
  onConfirm; // Optionnel pour simulation
  final bool isSimulationOnly; // Nouveau paramètre

  const EarlyRepaymentDialog({
    super.key,
    required this.loan,
    this.onConfirm,
    this.isSimulationOnly = true, // Par défaut en mode simulation
  });

  @override
  State<EarlyRepaymentDialog> createState() => _EarlyRepaymentDialogState();
}

class _EarlyRepaymentDialogState extends State<EarlyRepaymentDialog> {
  final _montantController = TextEditingController();
  final _dureeController = TextEditingController();
  final _noteController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  EarlyRepaymentOptions? _currentOptions;
  final _earlyRepaymentService = EarlyRepaymentService();
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    print(
      'EarlyRepaymentDialog - isSimulationOnly: ${widget.isSimulationOnly}',
    );
    // Valeurs par défaut
    _dureeController.text = (widget.loan.dureeMois ~/ 2)
        .toString(); // Moitié de la durée originale
    _montantController.text = (widget.loan.montant * 0.3).toStringAsFixed(
      0,
    ); // 30% du capital
    _calculateOptions();
  }

  void _calculateOptions() {
    final montantText = _montantController.text.trim();
    final dureeText = _dureeController.text.trim();

    if (montantText.isEmpty || dureeText.isEmpty) {
      setState(() {
        _currentOptions = null;
      });
      return;
    }

    final montant = double.tryParse(montantText);
    final duree = int.tryParse(dureeText);

    if (montant == null || duree == null || montant <= 0 || duree <= 0) {
      setState(() {
        _currentOptions = null;
      });
      return;
    }

    // Vérifications
    if (montant >= widget.loan.montant) {
      setState(() {
        _currentOptions = null;
      });
      return;
    }

    if (duree >= widget.loan.dureeMois) {
      setState(() {
        _currentOptions = null;
      });
      return;
    }

    setState(() {
      _isCalculating = true;
    });

    try {
      final options = _earlyRepaymentService.calculateEarlyRepaymentOptions(
        loan: widget.loan,
        montantAnticipe: montant,
        nouvelleDuree: duree,
      );

      setState(() {
        _currentOptions = options;
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _currentOptions = null;
        _isCalculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.payments,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isSimulationOnly
                              ? 'Simulation de remboursement'
                              : 'Traitement remboursement anticipé (ADMIN)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.isSimulationOnly
                              ? 'Simulez votre remboursement'
                              : 'Saisie et validation du remboursement',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations du prêt actuel
                    _buildCurrentLoanInfo(),
                    const SizedBox(height: 24),

                    // Formulaire de simulation
                    _buildSimulationForm(),
                    const SizedBox(height: 24),

                    // Résultats de la simulation
                    if (_isCalculating)
                      const Center(child: CircularProgressIndicator())
                    else if (_currentOptions != null)
                      _buildSimulationResults(),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentOptions == null
                          ? null
                          : () {
                              if (widget.isSimulationOnly) {
                                // Mode simulation - juste fermer le dialog
                                Navigator.pop(context);
                              } else {
                                // Mode admin - exécuter le callback
                                final montant = double.parse(
                                  _montantController.text,
                                );
                                final duree = int.parse(_dureeController.text);
                                widget.onConfirm?.call(montant, duree);
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isSimulationOnly
                            ? Colors.grey.shade600
                            : Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.isSimulationOnly ? 'Fermer' : 'Confirmer',
                      ),
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

  Widget _buildCurrentLoanInfo() {
    // coutTotalEstime est uniquement le montant des intérêts
    final interetsTotaux = widget.loan.coutTotalEstime;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prêt actuel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Capital',
                  _currencyFormat.format(widget.loan.montant),
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  'Durée',
                  '${widget.loan.dureeMois} mois',
                  Icons.schedule,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Mensualité',
                  _currencyFormat.format(widget.loan.mensualite),
                  Icons.payments,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  'Intérêts totaux',
                  _currencyFormat.format(interetsTotaux),
                  Icons.percent,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSimulationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Simulation de remboursement',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Montant anticipé
        TextFormField(
          controller: _montantController,
          decoration: InputDecoration(
            labelText: 'Montant à rembourser par anticipation',
            suffixText: '€',
            helperText:
                'Maximum: ${_currencyFormat.format(widget.loan.montant - 1)}',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.euro),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _calculateOptions(),
        ),
        const SizedBox(height: 16),

        // Nouvelle durée
        TextFormField(
          controller: _dureeController,
          decoration: InputDecoration(
            labelText: 'Nouvelle durée de remboursement',
            suffixText: 'mois',
            helperText: 'Maximum: ${widget.loan.dureeMois - 1} mois',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.schedule),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _calculateOptions(),
        ),
        const SizedBox(height: 16),

        // Note optionnelle
        TextFormField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: 'Note (optionnelle)',
            helperText: 'Raison du remboursement anticipé',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.note),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSimulationResults() {
    if (_currentOptions == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Résultat de la simulation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Résultats principaux
          Row(
            children: [
              Expanded(
                child: _buildResultItem(
                  'Nouvelle mensualité',
                  _currencyFormat.format(_currentOptions!.nouvelleMensualite),
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildResultItem(
                  'Économie de temps',
                  '${_currentOptions!.economieTemps} mois',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Détails supplémentaires
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  'Capital restant',
                  _currencyFormat.format(_currentOptions!.capitalRestant),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Intérêts conservés',
                  _currencyFormat.format(_currentOptions!.interetsConserves),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Total à rembourser',
                  _currencyFormat.format(_currentOptions!.montantTotalRestant),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Les intérêts totaux restent identiques, seule la répartition change.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _montantController.dispose();
    _dureeController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
