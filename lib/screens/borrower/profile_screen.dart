import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
                  // Header avec profil
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Avatar
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              user.nomComplet.isNotEmpty
                                  ? user.nomComplet[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.nomComplet,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Sections du profil
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Informations personnelles
                        _buildProfileSection('Informations personnelles', [
                          _buildProfileItem(
                            Icons.person,
                            'Nom complet',
                            user.nomComplet,
                            Colors.blue,
                          ),
                          _buildProfileItem(
                            Icons.email,
                            'Email',
                            user.email,
                            Colors.green,
                          ),
                          _buildProfileItem(
                            Icons.phone,
                            'Téléphone',
                            user.telephone,
                            Colors.orange,
                          ),
                          _buildProfileItem(
                            Icons.location_on,
                            'Adresse',
                            user.adresse,
                            Colors.purple,
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // Niveau de risque
                        _buildRiskSection(user),

                        const SizedBox(height: 20),

                        // Statistiques de prêt
                        Consumer<LoanProvider>(
                          builder: (context, loanProvider, child) {
                            final activeLoans = loanProvider.userLoans
                                .where((loan) => loan.isActive)
                                .length;
                            final totalBorrowed = loanProvider.userLoans
                                .where(
                                  (loan) => loan.isActive || loan.isCompleted,
                                )
                                .fold(0.0, (sum, loan) => sum + loan.montant);

                            return _buildProfileSection('Mes statistiques', [
                              _buildProfileItem(
                                Icons.trending_up,
                                'Prêts actifs',
                                '$activeLoans',
                                Colors.blue,
                              ),
                              _buildProfileItem(
                                Icons.euro,
                                'Total emprunté',
                                '${totalBorrowed.toStringAsFixed(0)}€',
                                Colors.green,
                              ),
                              _buildProfileItem(
                                Icons.history,
                                'Total des prêts',
                                '${loanProvider.userLoans.length}',
                                Colors.orange,
                              ),
                            ]);
                          },
                        ),

                        const SizedBox(height: 20),

                        // Actions
                        _buildProfileSection('Actions', [
                          _buildActionItem(
                            Icons.edit,
                            'Modifier le profil',
                            Colors.blue,
                            () {
                              context.push('/profile/edit');
                            },
                          ),
                          _buildActionItem(
                            Icons.security,
                            'Sécurité et confidentialité',
                            Colors.green,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Fonctionnalité en cours de développement',
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionItem(
                            Icons.help,
                            'Aide et support',
                            Colors.orange,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Fonctionnalité en cours de développement',
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionItem(
                            Icons.logout,
                            'Se déconnecter',
                            Colors.red,
                            () => _showLogoutDialog(context),
                          ),
                        ]),

                        const SizedBox(height: 30),
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

  Widget _buildProfileSection(String title, List<Widget> children) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
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
  }

  Widget _buildRiskSection(dynamic user) {
    final hasAssessment = user.niveauConfiance != null;
    final double level = (user.niveauConfiance ?? 0.0) as double;

    Color riskColor;
    IconData riskIcon;
    String riskLabel;
    String riskDescription;

    if (!hasAssessment) {
      riskColor = Colors.grey;
      riskIcon = Icons.help_outline;
      riskLabel = 'Non évalué';
      riskDescription = 'Votre niveau de risque n\'a pas encore été évalué.';
    } else if (level >= 4.0) {
      riskColor = Colors.green;
      riskIcon = Icons.verified_user;
      riskLabel = 'Faible risque';
      riskDescription =
          'Excellent ! Vous bénéficiez de taux préférentiels (divisés par 2).';
    } else if (level >= 2.0) {
      riskColor = Colors.orange;
      riskIcon = Icons.shield;
      riskLabel = 'Risque normal';
      riskDescription =
          'Votre profil est standard. Vos taux d\'intérêt sont normaux.';
    } else {
      riskColor = Colors.red;
      riskIcon = Icons.warning;
      riskLabel = 'Gros risque';
      riskDescription =
          'Attention ! Vos taux d\'intérêt sont doublés. Régularisez vos paiements.';
    }

    return _buildProfileSection('Mon niveau de risque', [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: riskColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: riskColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(riskIcon, color: riskColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          riskLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
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
                              color: riskColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${level.toStringAsFixed(1)}/5',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: riskColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riskDescription,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildActionItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Déconnexion'),
          ],
        ),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
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
              child: const Text(
                'Se déconnecter',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
