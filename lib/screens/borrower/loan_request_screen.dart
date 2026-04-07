import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/loan_provider.dart';
import '../../providers/auth_provider.dart';

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final _ribController = TextEditingController(); // NOUVEAU
  final _montantController = TextEditingController();
  final _dureeController = TextEditingController();
  // final _objetController = TextEditingController(); // SUPPRIMÉ
  final DateTime _dateSouhaitee = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _dureeController.text = '12';
  }

  @override
  void dispose() {
    _ribController.dispose();
    _montantController.dispose();
    _dureeController.dispose();
    // _objetController.dispose(); // SUPPRIMÉ
    super.dispose();
  }

  void _updateCalculations() {
    final montantText = _montantController.text;
    final dureeText = _dureeController.text;

    if (montantText.isEmpty || dureeText.isEmpty) return;

    final montant = double.tryParse(montantText) ?? 0;
    final duree = int.tryParse(dureeText) ?? 12;

    if (montant >= 10 && duree > 0) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final niveauConfiance = authProvider.currentUser?.niveauConfiance;

      Provider.of<LoanProvider>(context, listen: false).calculateLoanParameters(
        montant,
        duree,
        niveauConfiance: niveauConfiance,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Modern SliverAppBar avec gradient
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => context.go('/dashboard'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.request_quote,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Nouvelle demande',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Configurez votre prêt personnel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content moderne avec style Revolut
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Information de l'emprunteur (moderne Revolut)
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Emprunteur',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      authProvider.currentUser?.nomComplet ??
                                          'Non disponible',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
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
                    const SizedBox(height: 16),

                    // RIB du demandeur (moderne Revolut)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _ribController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'RIB/IBAN du compte à créditer',
                          hintText: 'FR76 1234 5678 9012 3456 7890 123',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.account_balance,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
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
                    const SizedBox(height: 16),

                    // Montant (moderne Revolut)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _montantController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Montant souhaité (€)',
                          hintText: 'ex: 1500',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.euro,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (_) => _updateCalculations(),
                        validator: (value) {
                          final montant = double.tryParse(value ?? '');
                          if (montant == null || montant < 10) {
                            return 'Montant minimum : 10€';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Durée (moderne Revolut)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _dureeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Durée (mois)',
                          hintText: 'ex: 12',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.purple, Colors.deepPurple],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.schedule,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (_) => _updateCalculations(),
                        validator: (value) {
                          final duree = int.tryParse(value ?? '');
                          if (duree == null || duree < 1 || duree > 60) {
                            return 'Durée entre 1 et 60 mois';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CHAMP "OBJET DU PRÊT" SUPPRIMÉ
                    const SizedBox(height: 24),

                    // Calculs en temps réel (moderne Revolut)
                    Consumer<LoanProvider>(
                      builder: (context, loanProvider, child) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Colors.blue, Colors.purple],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.calculate,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Simulation de votre prêt',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildSimulationRow(
                                  'Taux annuel',
                                  '${loanProvider.tauxCalcule.toStringAsFixed(2)}%',
                                ),
                                const SizedBox(height: 8),
                                _buildSimulationRow(
                                  'Mensualité',
                                  '${loanProvider.mensualiteCalculee.toStringAsFixed(2)}€',
                                ),
                                const SizedBox(height: 8),
                                _buildSimulationRow(
                                  'Montant emprunté',
                                  '${loanProvider.montant.toStringAsFixed(2)}€',
                                  isHighlighted: true,
                                ),
                                const SizedBox(height: 8),
                                _buildSimulationRow(
                                  'Coût total des intérêts',
                                  '${loanProvider.interetsTotaux.toStringAsFixed(2)}€',
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 8),
                                _buildSimulationRow(
                                  'Montant total à rembourser',
                                  '${loanProvider.montantTotalARembourser.toStringAsFixed(2)}€',
                                  color: Colors.green,
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bouton de soumission (moderne Revolut)
                    Consumer2<LoanProvider, AuthProvider>(
                      builder: (context, loanProvider, authProvider, child) {
                        return Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: loanProvider.isLoading
                                ? null
                                : const LinearGradient(
                                    colors: [Colors.blue, Colors.purple],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(20),
                            color: loanProvider.isLoading
                                ? Colors.grey[300]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: loanProvider.isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      final success = await loanProvider
                                          .createLoanRequest(
                                            userId:
                                                authProvider.currentUser!.id,
                                            nomEmprunteur: authProvider
                                                .currentUser!
                                                .nomComplet,
                                            ribEmprunteur: _ribController.text
                                                .trim(),
                                            montant: double.parse(
                                              _montantController.text,
                                            ),
                                            dureeMois: int.parse(
                                              _dureeController.text,
                                            ),
                                            // objetPret: _objetController.text.trim(), // SUPPRIMÉ
                                            dateSouhaitee: _dateSouhaitee,
                                          );

                                      if (success && mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Demande soumise avec succès !',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        context.go('/dashboard');
                                      } else if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              loanProvider.errorMessage ??
                                                  'Erreur',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: loanProvider.isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Soumettre ma demande de prêt',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
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
          ),
        ],
      ),
    );
  }

  // Méthode helper pour les lignes de simulation moderne
  Widget _buildSimulationRow(
    String label,
    String value, {
    bool isHighlighted = false,
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold
                ? FontWeight.bold
                : (isHighlighted ? FontWeight.w600 : FontWeight.w500),
            color: color ?? (isHighlighted ? Colors.black87 : Colors.black),
          ),
        ),
      ],
    );
  }
}
