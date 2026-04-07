// Modèle utilisateur avec sérialisation JSON manuelle

enum UserRole { borrower, admin, superAdmin }

class UserModel {
  final String id;
  final String nom;
  final String prenom; // NOUVEAU - Prénom séparé
  final String email;
  final String telephone;
  final String adresse;
  final String? ibanMasked;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Système de niveau de confiance (1.0 à 5.0)
  final double? niveauConfiance;
  final String? commentaireRisque;
  final DateTime? dernierEvaluationRisque;
  final String? evaluePar; // ID de l'admin qui a évalué

  const UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.adresse,
    this.ibanMasked,
    this.role = UserRole.borrower,
    required this.createdAt,
    this.updatedAt,
    this.niveauConfiance,
    this.commentaireRisque,
    this.dernierEvaluationRisque,
    this.evaluePar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Conversion manuelle pour gérer les formats de date et rôles
    UserRole parseRole(dynamic roleValue) {
      if (roleValue is String) {
        switch (roleValue.toLowerCase()) {
          case 'admin':
            return UserRole.admin;
          case 'superadmin':
          case 'super_admin':
            return UserRole.superAdmin;
          default:
            return UserRole.borrower;
        }
      }
      return UserRole.borrower;
    }

    DateTime parseDateTime(dynamic dateValue) {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return DateTime.now();
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? 'Nom',
      prenom: json['prenom']?.toString() ?? 'Prénom',
      email: json['email']?.toString() ?? '',
      telephone: json['telephone']?.toString() ?? '',
      adresse: json['adresse']?.toString() ?? '',
      ibanMasked: json['ibanMasked']?.toString(),
      role: parseRole(json['role']),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? parseDateTime(json['updatedAt'])
          : null,
      niveauConfiance: json['niveauConfiance']?.toDouble(),
      commentaireRisque: json['commentaireRisque']?.toString(),
      dernierEvaluationRisque: json['dernierEvaluationRisque'] != null
          ? parseDateTime(json['dernierEvaluationRisque'])
          : null,
      evaluePar: json['evaluePar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'adresse': adresse,
      'ibanMasked': ibanMasked,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'niveauConfiance': niveauConfiance,
      'commentaireRisque': commentaireRisque,
      'dernierEvaluationRisque': dernierEvaluationRisque?.toIso8601String(),
      'evaluePar': evaluePar,
    };
  }

  UserModel copyWith({
    String? id,
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    String? adresse,
    String? ibanMasked,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? niveauConfiance,
    String? commentaireRisque,
    DateTime? dernierEvaluationRisque,
    String? evaluePar,
  }) {
    return UserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      ibanMasked: ibanMasked ?? this.ibanMasked,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      niveauConfiance: niveauConfiance ?? this.niveauConfiance,
      commentaireRisque: commentaireRisque ?? this.commentaireRisque,
      dernierEvaluationRisque:
          dernierEvaluationRisque ?? this.dernierEvaluationRisque,
      evaluePar: evaluePar ?? this.evaluePar,
    );
  }

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isBorrower => role == UserRole.borrower;

  /// Retourne le nom complet (prénom + nom)
  String get nomComplet => '$prenom $nom'.trim();

  /// Helpers pour le niveau de confiance
  bool get hasRiskAssessment => niveauConfiance != null;

  String get riskLevel {
    if (niveauConfiance == null) return 'Non évalué';
    if (niveauConfiance! >= 4.0) return 'Faible risque';
    if (niveauConfiance! >= 2.0) return 'Risque normal';
    return 'Gros risque';
  }

  String get riskLevelColor {
    if (niveauConfiance == null) return 'grey';
    if (niveauConfiance! >= 4.0) return 'green';
    if (niveauConfiance! >= 2.0) return 'orange';
    return 'red';
  }
}
