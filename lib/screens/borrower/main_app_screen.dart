import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../config/app_theme.dart';
import '../../services/chat_service.dart';
import 'borrower_dashboard_screen.dart';
import 'my_loans_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'chat_screen.dart';

class MainAppScreen extends StatefulWidget {
  final String initialLocation;

  const MainAppScreen({super.key, this.initialLocation = '/dashboard'});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  final List<Widget> _staticScreens = [
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
      case '/chat':
        _currentIndex = 2;
        break;
      case '/notifications':
        _currentIndex = 3;
        break;
      case '/profile':
        _currentIndex = 4;
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
    final screens = [
      _staticScreens[0],
      _staticScreens[1],
      ChatScreen(isVisible: _currentIndex == 2),
      _staticScreens[2],
      _staticScreens[3],
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F1F5), width: 1)),
        ),
        child: SafeArea(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  label: 'Accueil',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.receipt_long_rounded,
                  inactiveIcon: Icons.receipt_long_outlined,
                  label: 'Prêts',
                ),
                _buildChatNavItem(),
                _buildNavItem(
                  index: 3,
                  icon: Icons.notifications_rounded,
                  inactiveIcon: Icons.notifications_outlined,
                  label: 'Alertes',
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
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
            context.go('/chat');
            break;
          case 3:
            context.go('/notifications');
            break;
          case 4:
            context.go('/profile');
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? icon : inactiveIcon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : const Color(0xFFB0B7C3),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : const Color(0xFFB0B7C3),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatNavItem() {
    final isSelected = _currentIndex == 2;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = 2);
        context.go('/chat');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFFB0B7C3),
                  size: 24,
                ),
                if (userId != null)
                  StreamBuilder<int>(
                    stream: ChatService().getUnreadCountForUser(userId),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Contact',
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : const Color(0xFFB0B7C3),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
