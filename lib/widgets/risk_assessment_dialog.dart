import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/risk_assessment_service.dart';

class RiskAssessmentDialog extends StatefulWidget {
  final UserModel user;

  const RiskAssessmentDialog({super.key, required this.user});

  @override
  State<RiskAssessmentDialog> createState() => _RiskAssessmentDialogState();
}

class _RiskAssessmentDialogState extends State<RiskAssessmentDialog> {
  final RiskAssessmentService _riskService = RiskAssessmentService();
  final TextEditingController _commentController = TextEditingController();
  double _selectedRisk = 3.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les valeurs existantes si disponibles
    if (widget.user.niveauConfiance != null) {
      _selectedRisk = widget.user.niveauConfiance!;
    }
    if (widget.user.commentaireRisque != null) {
      _commentController.text = widget.user.commentaireRisque!;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveAssessment() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _riskService.updateRiskAssessment(
        userId: widget.user.id,
        niveauConfiance: _selectedRisk,
        adminId: authProvider.currentUser!.id,
        commentaire: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (success && mounted) {
        Navigator.of(
          context,
        ).pop(true); // Retourner true pour indiquer le succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Évaluation de risque mise à jour pour ${widget.user.nomComplet}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour'),
            backgroundColor: Colors.red,
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getRiskLabel(double risk) {
    if (risk >= 4.0) return 'Faible risque';
    if (risk >= 2.0) return 'Risque normal';
    return 'Gros risque';
  }

  Color _getRiskColor(double risk) {
    if (risk >= 4.0) return Colors.green;
    if (risk >= 2.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assessment, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Évaluation de risque',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.user.nomComplet,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations client
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Client: ${widget.user.nomComplet}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(widget.user.email),
                    ],
                  ),
                  if (widget.user.hasRiskAssessment) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.history, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Dernière évaluation: ${widget.user.dernierEvaluationRisque != null ? DateFormat('dd/MM/yyyy').format(widget.user.dernierEvaluationRisque!) : 'N/A'}',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sélecteur de niveau de risque
            const Text(
              'Niveau de confiance (1 = Gros risque, 5 = Faible risque)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Slider avec indicateurs visuels
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _selectedRisk,
                        min: 1.0,
                        max: 5.0,
                        divisions: 8, // Permet des valeurs comme 1.5, 2.5, etc.
                        label: _selectedRisk.toString(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRisk = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                // Indicateur visuel du niveau de risque
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getRiskColor(_selectedRisk).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getRiskColor(_selectedRisk).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedRisk >= 4.0
                            ? Icons.check_circle
                            : _selectedRisk >= 2.0
                            ? Icons.warning
                            : Icons.error,
                        color: _getRiskColor(_selectedRisk),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedRisk.toString()} - ${_getRiskLabel(_selectedRisk)}',
                        style: TextStyle(
                          color: _getRiskColor(_selectedRisk),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Impact sur les taux
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Impact sur les taux d\'intérêt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedRisk >= 4.0
                        ? '• Taux divisé par 2 (client de confiance)'
                        : _selectedRisk >= 2.0
                        ? '• Taux normal (client standard)'
                        : '• Taux doublé (client à risque)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Commentaire
            const Text(
              'Commentaire (optionnel)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Détails sur l\'évaluation, historique de paiement, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAssessment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
