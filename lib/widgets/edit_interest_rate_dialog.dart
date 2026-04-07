import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/loan_model.dart';

class EditInterestRateDialog extends StatefulWidget {
  final LoanModel loan;

  const EditInterestRateDialog({super.key, required this.loan});

  @override
  State<EditInterestRateDialog> createState() => _EditInterestRateDialogState();
}

class _EditInterestRateDialogState extends State<EditInterestRateDialog> {
  late TextEditingController _rateController;
  late double _currentRate;
  double _newMensualite = 0;
  double _newTotalCost = 0;
  bool _isCalculating = false;

  // Valeurs actuelles recalculées avec la méthode simple
  late double _currentMensualite;
  late double _currentTotalCost;
  late double _currentInterests;

  /// Formate un montant en euro en préservant la précision exacte
  String _formatAmount(double amount) {
    // Pour éviter les erreurs de formatage, on utilise une approche simple
    // On affiche le nombre tel qu'il est stocké (sans arrondir)

    // Si c'est un entier exact, on affiche sans décimales
    if (amount == amount.roundToDouble()) {
      return '${amount.round()}€';
    }

    // Sinon, on utilise le formatage par défaut avec 2 décimales
    return '${amount.toStringAsFixed(2)}€';
  }

  @override
  void initState() {
    super.initState();
    _currentRate = widget.loan.tauxAnnuel;
    _rateController = TextEditingController(
      text: _currentRate.toStringAsFixed(2),
    );

    // Calculer les valeurs actuelles avec la méthode simple
    _calculateCurrentAmounts();
    _calculateNewAmounts();

    _rateController.addListener(_onRateChanged);
  }

  void _calculateCurrentAmounts() {
    // Utiliser les valeurs réelles stockées dans la base
    _currentMensualite = widget.loan.mensualite;
    _currentInterests =
        widget.loan.coutTotalEstime; // coût des intérêts uniquement
    _currentTotalCost =
        widget.loan.montant +
        widget.loan.coutTotalEstime; // capital + intérêts = coût total

    // Debug pour vérifier les valeurs exactes
    print('🔍 DEBUG EditInterestRateDialog:');
    print('   - loan.coutTotalEstime: ${widget.loan.coutTotalEstime}');
    print('   - loan.mensualite: ${widget.loan.mensualite}');
    print('   - loan.montant: ${widget.loan.montant}');
    print('   - _currentInterests: $_currentInterests');
    print('   - _currentTotalCost: $_currentTotalCost');
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  void _onRateChanged() {
    if (_rateController.text.isNotEmpty) {
      final newRate = double.tryParse(_rateController.text);
      if (newRate != null && newRate >= 0 && newRate <= 100) {
        setState(() {
          _currentRate = newRate;
          _calculateNewAmounts();
        });
      }
    }
  }

  void _calculateNewAmounts() {
    setState(() {
      _isCalculating = true;
    });

    // Calcul CORRECT : intérêts exacts sans arrondi intermédiaire
    final montant = widget.loan.montant;
    final dureeMois = widget.loan.dureeMois;

    if (_currentRate == 0) {
      _newMensualite = montant / dureeMois;
      _newTotalCost = montant;
    } else {
      // TAUX SIMPLE : intérêts fixes calculés sur le capital initial
      final interetsTotaux = montant * (_currentRate / 100);
      _newTotalCost = montant + interetsTotaux;
      _newMensualite = _newTotalCost / dureeMois;

      // Arrondir seulement la mensualité pour l'affichage
      _newMensualite = double.parse(_newMensualite.toStringAsFixed(2));
    }

    setState(() {
      _isCalculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.percent,
              color: Color(0xFF00D4FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Modifier le taux d\'intérêt',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informations du prêt
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E27),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prêt de ${widget.loan.montant.toStringAsFixed(0)}€',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Durée: ${widget.loan.dureeMois} mois',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Emprunteur: ${widget.loan.nomEmprunteur}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Modification du taux
              Text(
                'Nouveau taux d\'intérêt annuel',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  suffixText: '%',
                  suffixStyle: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 18,
                  ),
                  hintText: 'Ex: 5.50',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00D4FF)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0A0E27),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),

              // Aperçu des calculs
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E27),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Aperçu des nouveaux montants',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isCalculating)
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00D4FF),
                        ),
                        strokeWidth: 2,
                      )
                    else ...[
                      // Informations fixes
                      _buildInfoRow(
                        'Montant demandé',
                        '${widget.loan.montant.toStringAsFixed(0)}€',
                      ),
                      const SizedBox(height: 8),
                      _buildComparisonRow(
                        'Taux d\'intérêt',
                        '${widget.loan.tauxAnnuel.toStringAsFixed(2)}%',
                        '${_currentRate.toStringAsFixed(2)}%',
                      ),
                      const SizedBox(height: 8),
                      _buildComparisonRow(
                        'Coût intérêt',
                        _formatAmount(_currentInterests),
                        _formatAmount(_newTotalCost - widget.loan.montant),
                      ),
                      const SizedBox(height: 8),
                      _buildComparisonRow(
                        'Coût total',
                        _formatAmount(_currentTotalCost),
                        _formatAmount(_newTotalCost),
                      ),
                      const SizedBox(height: 8),
                      _buildComparisonRow(
                        'Mensualité',
                        '${_currentMensualite.toStringAsFixed(2)}€',
                        '${_newMensualite.toStringAsFixed(2)}€',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Annuler',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _currentRate != widget.loan.tauxAnnuel
              ? () {
                  Navigator.of(context).pop(_currentRate);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String label, String oldValue, String newValue) {
    final isIncrease =
        double.parse(newValue.replaceAll('€', '').replaceAll('%', '')) >
        double.parse(oldValue.replaceAll('€', '').replaceAll('%', ''));

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            oldValue,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, color: Color(0xFF00D4FF), size: 12),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                newValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isIncrease ? Icons.trending_up : Icons.trending_down,
                color: isIncrease ? Colors.red : Colors.green,
                size: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
