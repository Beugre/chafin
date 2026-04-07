import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/risk_assessment_service.dart';
import '../../widgets/risk_assessment_dialog.dart';

class RiskManagementScreen extends StatefulWidget {
  const RiskManagementScreen({super.key});

  @override
  State<RiskManagementScreen> createState() => _RiskManagementScreenState();
}

class _RiskManagementScreenState extends State<RiskManagementScreen> {
  final RiskAssessmentService _riskService = RiskAssessmentService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter =
      'all'; // all, evaluated, non_evaluated, high_risk, low_risk
  Map<String, dynamic> _statistics = {};
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    await adminProvider.loadAllUsers();
    await _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await _riskService.getRiskStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      print('Erreur lors du chargement des statistiques: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  List<UserModel> _getFilteredUsers(List<UserModel> users) {
    return users.where((user) {
      // Filtre par rôle (seulement les emprunteurs)
      if (user.role != UserRole.borrower) return false;

      // Filtre par recherche
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!user.nomComplet.toLowerCase().contains(query) &&
            !user.email.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Filtre par statut d'évaluation
      switch (_selectedFilter) {
        case 'evaluated':
          return user.hasRiskAssessment;
        case 'non_evaluated':
          return !user.hasRiskAssessment;
        case 'high_risk':
          return user.niveauConfiance != null && user.niveauConfiance! < 2.0;
        case 'low_risk':
          return user.niveauConfiance != null && user.niveauConfiance! >= 4.0;
        case 'normal_risk':
          return user.niveauConfiance != null &&
              user.niveauConfiance! >= 2.0 &&
              user.niveauConfiance! < 4.0;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _showRiskAssessmentDialog(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RiskAssessmentDialog(user: user),
    );

    if (result == true) {
      // Recharger les données après une modification
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Gestion des risques clients',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Statistiques
          if (!_isLoadingStats && _statistics.isNotEmpty)
            _buildStatisticsCard(),

          // Filtres et recherche
          _buildFiltersSection(),

          // Liste des utilisateurs
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, adminProvider, child) {
                if (adminProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  );
                }

                final filteredUsers = _getFilteredUsers(adminProvider.allUsers);

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun client trouvé',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Essayez de modifier vos critères de recherche',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _buildUserCard(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Statistiques des évaluations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total clients',
                  _statistics['totalUsers']?.toString() ?? '0',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Évalués',
                  _statistics['evaluatedUsers']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Non évalués',
                  _statistics['nonEvaluatedUsers']?.toString() ?? '0',
                  Icons.pending,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Faible risque',
                  _statistics['faibleRisque']?.toString() ?? '0',
                  Icons.verified,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Risque normal',
                  _statistics['risqueNormal']?.toString() ?? '0',
                  Icons.info,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Gros risque',
                  _statistics['grosRisque']?.toString() ?? '0',
                  Icons.warning,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // Filtres
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tous', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Évalués', 'evaluated'),
                const SizedBox(width: 8),
                _buildFilterChip('Non évalués', 'non_evaluated'),
                const SizedBox(width: 8),
                _buildFilterChip('Faible risque', 'low_risk'),
                const SizedBox(width: 8),
                _buildFilterChip('Risque normal', 'normal_risk'),
                const SizedBox(width: 8),
                _buildFilterChip('Gros risque', 'high_risk'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Text(
                  user.nomComplet
                      .split(' ')
                      .map((e) => e[0])
                      .take(2)
                      .join()
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Informations utilisateur
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nomComplet,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Badge de niveau de risque
              if (user.hasRiskAssessment) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user.riskLevelColor == 'green'
                        ? Colors.green.withOpacity(0.1)
                        : user.riskLevelColor == 'orange'
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.riskLevel,
                    style: TextStyle(
                      color: user.riskLevelColor == 'green'
                          ? Colors.green
                          : user.riskLevelColor == 'orange'
                          ? Colors.orange
                          : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Non évalué',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (user.hasRiskAssessment) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Niveau: ${user.niveauConfiance!.toString()}/5',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (user.commentaireRisque != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.commentaireRisque!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                  if (user.dernierEvaluationRisque != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Évalué le ${DateFormat('dd/MM/yyyy').format(user.dernierEvaluationRisque!)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Bouton d'action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRiskAssessmentDialog(user),
              icon: Icon(
                user.hasRiskAssessment ? Icons.edit : Icons.add,
                size: 16,
              ),
              label: Text(
                user.hasRiskAssessment
                    ? 'Modifier l\'évaluation'
                    : 'Évaluer le risque',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
