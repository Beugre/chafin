import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _adresseController = TextEditingController();

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      _nomController.text = user.nom;
      _prenomController.text = user.prenom;
      _telephoneController.text = user.telephone;
      _adresseController.text = user.adresse;

      _nomController.addListener(_onFieldChanged);
      _prenomController.addListener(_onFieldChanged);
      _telephoneController.addListener(_onFieldChanged);
      _adresseController.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      final hasChanges =
          _nomController.text != user.nom ||
          _prenomController.text != user.prenom ||
          _telephoneController.text != user.telephone ||
          _adresseController.text != user.adresse;
      if (hasChanges != _hasChanges) {
        setState(() => _hasChanges = hasChanges);
      }
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      if (user != null) {
        final updatedUser = user.copyWith(
          nom: _nomController.text.trim(),
          prenom: _prenomController.text.trim(),
          telephone: _telephoneController.text.trim(),
          adresse: _adresseController.text.trim(),
          updatedAt: DateTime.now(),
        );
        final success = await Provider.of<AuthProvider>(
          context,
          listen: false,
        ).updateProfile(updatedUser);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour avec succès'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Modifications non sauvegardées',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            content: const Text(
              'Voulez-vous vraiment quitter sans sauvegarder ?',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Rester',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Quitter',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop() && mounted) context.pop();
      },
      child: Scaffold(
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
            onPressed: () async {
              if (await _onWillPop()) context.pop();
            },
          ),
          title: const Text(
            'Modifier le profil',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
          actions: [
            if (_hasChanges && !_isLoading)
              TextButton(
                onPressed: _updateProfile,
                child: const Text(
                  'Sauvegarder',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.currentUser;
            if (user == null) {
              return const Center(child: Text('Utilisateur non trouvé'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Center(
                              child: Text(
                                user.nomComplet.isNotEmpty
                                    ? user.nomComplet[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
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

                    const SizedBox(height: 32),

                    const Text(
                      'INFORMATIONS PERSONNELLES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Formulaire dans une seule carte
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          _buildField(
                            controller: _prenomController,
                            label: 'Prénom',
                            icon: Icons.person_outline,
                            isFirst: true,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Requis';
                              if (v.trim().length < 2)
                                return 'Minimum 2 caractères';
                              return null;
                            },
                          ),
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: Color(0xFFE5E7EB),
                          ),
                          _buildField(
                            controller: _nomController,
                            label: 'Nom de famille',
                            icon: Icons.badge_outlined,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Requis';
                              if (v.trim().length < 2)
                                return 'Minimum 2 caractères';
                              return null;
                            },
                          ),
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: Color(0xFFE5E7EB),
                          ),
                          _buildField(
                            controller: _telephoneController,
                            label: 'Téléphone',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Requis';
                              if (v.trim().length < 10)
                                return 'Minimum 10 chiffres';
                              return null;
                            },
                          ),
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: Color(0xFFE5E7EB),
                          ),
                          _buildField(
                            controller: _adresseController,
                            label: 'Adresse',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                            isLast: true,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Requis';
                              if (v.trim().length < 5)
                                return 'Minimum 5 caractères';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Bouton sauvegarder
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: (_hasChanges && !_isLoading)
                              ? AppTheme.primaryGradient
                              : null,
                          color: (_hasChanges && !_isLoading)
                              ? null
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: (_hasChanges && !_isLoading)
                              ? _updateProfile
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
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
                                  'Sauvegarder les modifications',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isFirst = false,
    bool isLast = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: AppTheme.textPrimaryColor,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        errorStyle: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
        contentPadding: EdgeInsets.fromLTRB(
          16,
          isFirst ? 14 : 12,
          16,
          isLast ? 14 : 12,
        ),
      ),
    );
  }
}
