import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import 'borrower_dashboard_screen.dart';
import 'my_loans_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class MainAppScreen extends StatefulWidget {
  final String initialLocation;

  const MainAppScreen({super.key, this.initialLocation = '/dashboard'});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const BorrowerDashboardScreen(),
    const MyLoansScreen(),
    const BorrowerNotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Déterminer l'index initial basé sur la route
    switch (widget.initialLocation) {
      case '/dashboard':
        _currentIndex = 0;
        break;
      case '/my-loans':
        _currentIndex = 1;
        break;
      case '/notifications':
        _currentIndex = 2;
        break;
      case '/profile':
        _currentIndex = 3;
        break;
      default:
        _currentIndex = 0;
    }

    // Charger les données utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      loanProvider.loadUserLoans(authProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_filled,
                  inactiveIcon: Icons.home_outlined,
                  label: 'Accueil',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.account_balance_wallet,
                  inactiveIcon: Icons.account_balance_wallet_outlined,
                  label: 'Mes Prêts',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.notifications,
                  inactiveIcon: Icons.notifications_outlined,
                  label: 'Notifications',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person,
                  inactiveIcon: Icons.person_outline,
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });

        // Mettre à jour l'URL pour la navigation
        switch (index) {
          case 0:
            context.go('/dashboard');
            break;
          case 1:
            context.go('/my-loans');
            break;
          case 2:
            context.go('/notifications');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? icon : inactiveIcon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
