import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/loan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ribController = TextEditingController();
  final _montantController = TextEditingController();
  final _parrainEmailController = TextEditingController();
  int _selectedDuree = 6;
  final DateTime _dateSouhaitee = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _ribController.dispose();
    _montantController.dispose();
    _parrainEmailController.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    final montantText = _montantController.text;
    if (montantText.isEmpty) return;
    final montant = double.tryParse(montantText) ?? 0;
    if (montant >= 10) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<LoanProvider>(context, listen: false).calculateLoanParameters(
        montant,
        _selectedDuree,
        niveauConfiance: authProvider.currentUser?.niveauConfiance,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.textPrimaryColor,
            size: 20,
          ),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text(
          'Nouvelle demande',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emprunteur
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final user = authProvider.currentUser;
                  return _buildCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: Text(
                              user?.nomComplet.isNotEmpty == true
                                  ? user!.nomComplet[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Emprunteur',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.nomComplet ?? 'Non disponible',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // RIB
              _buildCard(
                child: TextFormField(
                  controller: _ribController,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _fieldDecoration(
                    'RIB / IBAN',
                    Icons.account_balance_outlined,
                    'FR76 3000 4000 …',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le RIB est obligatoire';
                    }
                    if (value.trim().length < 15) {
                      return 'RIB invalide (trop court)';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Montant
              _buildCard(
                child: TextFormField(
                  controller: _montantController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _fieldDecoration(
                    'Montant souhaité (€)',
                    Icons.euro_outlined,
                    '1 500',
                  ),
                  onChanged: (_) => _updateCalculations(),
                  validator: (value) {
                    final montant = double.tryParse(value ?? '');
                    if (montant == null || montant < 10) {
                      return 'Montant minimum : 10 €';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Parrain Email
              Consumer<LoanProvider>(
                builder: (context, loanProvider, child) {
                  final hasExistingLoans = loanProvider.userLoans.isNotEmpty;
                  return _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              color: Colors.purple[400],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Parrainage',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple[400],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Optionnel',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.purple[300],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (hasExistingLoans)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Vous avez déjà un prêt chez Chafin. '
                                    'Le parrainage est réservé aux nouveaux emprunteurs. '
                                    'Vous pouvez toutefois parrainer d\'autres personnes depuis votre profil.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[800],
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          TextFormField(
                            controller: _parrainEmailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _fieldDecoration(
                              'Email du parrain',
                              Icons.person_add_outlined,
                              'parrain@email.com',
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final emailRegex = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                );
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Email invalide';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Votre parrain recevra une commission de 20% des intérêts',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple[300],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Durée — chips
              const Text(
                'DURÉE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final mois = i + 1;
                  final selected = _selectedDuree == mois;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDuree = mois);
                      _updateCalculations();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: selected ? AppTheme.primaryGradient : null,
                        color: selected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(
                                    0.35,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${mois}M',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // Simulation card
              Consumer<LoanProvider>(
                builder: (context, loanProvider, child) {
                  final montant = double.tryParse(_montantController.text) ?? 0;
                  final hasData = montant >= 10;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIMULATION',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasData
                              ? '${loanProvider.mensualiteCalculee.toStringAsFixed(2)} €'
                              : '— €',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'par mois',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),
                        _simRow(
                          'Taux annuel',
                          hasData
                              ? '${loanProvider.tauxCalcule.toStringAsFixed(2)} %'
                              : '—',
                        ),
                        const SizedBox(height: 10),
                        _simRow(
                          'Montant emprunté',
                          hasData
                              ? '${loanProvider.montant.toStringAsFixed(2)} €'
                              : '—',
                        ),
                        const SizedBox(height: 10),
                        _simRow(
                          'Coût des intérêts',
                          hasData
                              ? '${loanProvider.interetsTotaux.toStringAsFixed(2)} €'
                              : '—',
                        ),
                        const SizedBox(height: 10),
                        _simRow(
                          'Total à rembourser',
                          hasData
                              ? '${loanProvider.montantTotalARembourser.toStringAsFixed(2)} €'
                              : '—',
                          bold: true,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Bouton soumettre
              Consumer2<LoanProvider, AuthProvider>(
                builder: (context, loanProvider, authProvider, child) {
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: loanProvider.isLoading
                            ? null
                            : AppTheme.primaryGradient,
                        color: loanProvider.isLoading ? Colors.grey[300] : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: loanProvider.isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(
                                    0.35,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: loanProvider.isLoading
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  final success = await loanProvider
                                      .createLoanRequest(
                                        userId: authProvider.currentUser!.id,
                                        nomEmprunteur: authProvider
                                            .currentUser!
                                            .nomComplet,
                                        ribEmprunteur: _ribController.text
                                            .trim(),
                                        montant: double.parse(
                                          _montantController.text,
                                        ),
                                        dureeMois: _selectedDuree,
                                        dateSouhaitee: _dateSouhaitee,
                                        parrainEmail:
                                            _parrainEmailController.text
                                                .trim()
                                                .isNotEmpty
                                            ? _parrainEmailController.text
                                                  .trim()
                                            : null,
                                      );
                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Demande soumise avec succès !',
                                        ),
                                        backgroundColor: AppTheme.successColor,
                                      ),
                                    );
                                    context.go('/dashboard');
                                  } else if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loanProvider.errorMessage ?? 'Erreur',
                                        ),
                                        backgroundColor: AppTheme.errorColor,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: loanProvider.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Soumettre ma demande',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: AppTheme.textSecondaryColor,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(color: AppTheme.textHintColor, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      errorStyle: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  Widget _simRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
