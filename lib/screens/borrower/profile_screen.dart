import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../config/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.currentUser;

            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Header blanc Revolut
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Center(
                            child: Text(
                              user.nomComplet.isNotEmpty
                                  ? user.nomComplet[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.nomComplet,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // Informations personnelles
                        _buildSectionTitle('Informations personnelles'),
                        const SizedBox(height: 8),
                        _buildListCard([
                          _buildListItem(
                            Icons.phone_outlined,
                            'Téléphone',
                            user.telephone,
                          ),
                          _buildDivider(),
                          _buildListItem(
                            Icons.location_on_outlined,
                            'Adresse',
                            user.adresse,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Niveau de risque
                        _buildSectionTitle('Niveau de confiance'),
                        const SizedBox(height: 8),
                        _buildRiskCard(user),

                        const SizedBox(height: 24),

                        // Statistiques
                        _buildSectionTitle('Statistiques'),
                        const SizedBox(height: 8),
                        Consumer<LoanProvider>(
                          builder: (context, loanProvider, child) {
                            final activeLoans = loanProvider.userLoans
                                .where((l) => l.isActive)
                                .length;
                            final totalBorrowed = loanProvider.userLoans
                                .where((l) => l.isActive || l.isCompleted)
                                .fold(0.0, (sum, l) => sum + l.montant);

                            return _buildListCard([
                              _buildStatItem(
                                'Prêts actifs',
                                '$activeLoans',
                                AppTheme.primaryColor,
                              ),
                              _buildDivider(),
                              _buildStatItem(
                                'Total emprunté',
                                '${totalBorrowed.toStringAsFixed(0)} €',
                                AppTheme.successColor,
                              ),
                              _buildDivider(),
                              _buildStatItem(
                                'Nb total de prêts',
                                '${loanProvider.userLoans.length}',
                                AppTheme.warningColor,
                              ),
                            ]);
                          },
                        ),

                        const SizedBox(height: 24),

                        // Actions
                        _buildSectionTitle('Compte'),
                        const SizedBox(height: 8),
                        _buildListCard([
                          _buildActionItem(
                            context,
                            Icons.security_outlined,
                            'Sécurité et confidentialité',
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Fonctionnalité en cours de développement',
                                    ),
                                  ),
                                ),
                          ),
                          _buildDivider(),
                          _buildActionItem(
                            context,
                            Icons.help_outline,
                            'Aide et support',
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Fonctionnalité en cours de développement',
                                    ),
                                  ),
                                ),
                          ),
                          _buildDivider(),
                          _buildActionItem(
                            context,
                            Icons.logout,
                            'Se déconnecter',
                            color: AppTheme.errorColor,
                            onTap: () => _showLogoutDialog(context),
                          ),
                        ]),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondaryColor,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildListCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 56,
      endIndent: 0,
      color: Color(0xFFE5E7EB),
    );
  }

  Widget _buildListItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? AppTheme.textPrimaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppTheme.textHintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskCard(dynamic user) {
    final hasAssessment = user.niveauConfiance != null;
    final double level = (user.niveauConfiance ?? 0.0) as double;

    Color color;
    String label;
    String description;

    if (!hasAssessment) {
      color = AppTheme.textSecondaryColor;
      label = 'Non évalué';
      description = 'Votre niveau de risque n\'a pas encore été évalué.';
    } else if (level >= 4.0) {
      color = AppTheme.successColor;
      label = 'Faible risque';
      description = 'Excellent ! Vous bénéficiez de taux préférentiels.';
    } else if (level >= 2.0) {
      color = AppTheme.warningColor;
      label = 'Risque normal';
      description = 'Profil standard, taux d\'intérêt normaux.';
    } else {
      color = AppTheme.errorColor;
      label = 'Risque élevé';
      description = 'Taux d\'intérêt majorés. Régularisez vos paiements.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              level >= 4.0
                  ? Icons.verified_outlined
                  : level >= 2.0
                  ? Icons.shield_outlined
                  : Icons.warning_amber_outlined,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (hasAssessment) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${level.toStringAsFixed(1)}/5',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Se déconnecter ?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final loanProvider = Provider.of<LoanProvider>(
                context,
                listen: false,
              );
              await Provider.of<AuthProvider>(
                context,
                listen: false,
              ).signOutAndClearData(loanProvider);
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Se déconnecter',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
