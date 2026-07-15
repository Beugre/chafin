// Modèle de prêt avec sérialisation JSON manuelle

enum LoanStatus {
  brouillon,
  soumis,
  enRevue,
  approuve,
  refuse,
  decaissementEffectue,
  enCours,
  solde,
  enRetard,
  annule,
  ferme, // Nouveau statut pour les prêts clôturés automatiquement
}

class LoanModel {
  final String id;
  final String userId;
  final String nomEmprunteur; // NOUVEAU - Nom de l'emprunteur
  final String ribEmprunteur; // NOUVEAU - RIB du demandeur
  final double montant;
  final int dureeMois;
  final double tauxBase;
  final double coefficientDuree;
  final double tauxAnnuel;
  final double mensualite;
  final double coutTotalEstime;
  // final String objetPret; // SUPPRIMÉ - champ non nécessaire
  final DateTime dateSouhaitee;
  final DateTime
  datePremierRemboursement; // NOUVEAU - Date calculée automatiquement
  final LoanStatus statut;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? disbursedAt;
  final DateTime? updatedAt;
  final String? noteAdmin;
  final String? referenceDecaissement;
  final DateTime? dateVirement; // NOUVEAU - Date du virement effectué

  // Champs pour le remboursement anticipé
  final bool
  peutRemboursementAnticipe; // Si le prêt permet le remboursement anticipé
  final DateTime?
  dateRemboursementAnticipe; // Date du remboursement anticipé effectué
  final double?
  montantRemboursementAnticipe; // Montant remboursé par anticipation
  final int? nouvelleDureeMois; // Nouvelle durée après remboursement anticipé

  // Parrainage
  final String? parrainEmail; // Email du parrain (uniquement si premier prêt)

  // Flags de contrôle admin
  final bool emailsDisabled; // Désactiver les emails de relance pour ce prêt
  final bool penaltiesDisabled; // Désactiver les pénalités pour ce prêt
  final String? reconnaissanceDetteUrl; // URL du PDF reconnaissance de dette

  const LoanModel({
    required this.id,
    required this.userId,
    required this.nomEmprunteur,
    required this.ribEmprunteur,
    required this.montant,
    required this.dureeMois,
    required this.tauxBase,
    required this.coefficientDuree,
    required this.tauxAnnuel,
    required this.mensualite,
    required this.coutTotalEstime,
    // required this.objetPret, // SUPPRIMÉ
    required this.dateSouhaitee,
    required this.datePremierRemboursement,
    this.statut = LoanStatus.brouillon,
    required this.createdAt,
    this.approvedAt,
    this.disbursedAt,
    this.updatedAt,
    this.noteAdmin,
    this.referenceDecaissement,
    this.dateVirement,
    this.peutRemboursementAnticipe =
        true, // Par défaut, tous les prêts permettent le remboursement anticipé
    this.dateRemboursementAnticipe,
    this.montantRemboursementAnticipe,
    this.nouvelleDureeMois,
    this.parrainEmail,
    this.emailsDisabled = false,
    this.penaltiesDisabled = false,
    this.reconnaissanceDetteUrl,
  });

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    // Conversion manuelle sécurisée pour gérer les null
    LoanStatus parseStatus(dynamic statusValue) {
      if (statusValue is String) {
        switch (statusValue) {
          case 'brouillon':
            return LoanStatus.brouillon;
          case 'soumis':
            return LoanStatus.soumis;
          case 'enRevue':
            return LoanStatus.enRevue;
          case 'approuve':
            return LoanStatus.approuve;
          case 'refuse':
            return LoanStatus.refuse;
          case 'decaissementEffectue':
            return LoanStatus.decaissementEffectue;
          case 'enCours':
            return LoanStatus.enCours;
          case 'solde':
            return LoanStatus.solde;
          case 'enRetard':
            return LoanStatus.enRetard;
          case 'annule':
            return LoanStatus.annule;
          case 'ferme':
            return LoanStatus.ferme;
          default:
            return LoanStatus.brouillon;
        }
      }
      return LoanStatus.brouillon;
    }

    DateTime parseDateTime(dynamic dateValue) {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return DateTime.now();
    }

    DateTime? parseOptionalDateTime(dynamic dateValue) {
      if (dateValue != null && dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return null;
    }

    return LoanModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      nomEmprunteur: json['nomEmprunteur']?.toString() ?? '',
      ribEmprunteur: json['ribEmprunteur']?.toString() ?? '',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      dureeMois: (json['dureeMois'] as num?)?.toInt() ?? 0,
      tauxBase: (json['tauxBase'] as num?)?.toDouble() ?? 0.0,
      coefficientDuree: (json['coefficientDuree'] as num?)?.toDouble() ?? 0.0,
      tauxAnnuel: (json['tauxAnnuel'] as num?)?.toDouble() ?? 0.0,
      mensualite: (json['mensualite'] as num?)?.toDouble() ?? 0.0,
      coutTotalEstime: (json['coutTotalEstime'] as num?)?.toDouble() ?? 0.0,
      // objetPret: json['objetPret']?.toString() ?? '', // SUPPRIMÉ
      dateSouhaitee: parseDateTime(json['dateSouhaitee']),
      datePremierRemboursement: parseDateTime(json['datePremierRemboursement']),
      statut: parseStatus(json['statut']),
      createdAt: parseDateTime(json['createdAt']),
      approvedAt: parseOptionalDateTime(json['approvedAt']),
      disbursedAt: parseOptionalDateTime(json['disbursedAt']),
      updatedAt: parseOptionalDateTime(json['updatedAt']),
      noteAdmin: json['noteAdmin']?.toString(),
      referenceDecaissement: json['referenceDecaissement']?.toString(),
      dateVirement: parseOptionalDateTime(json['dateVirement']),
      peutRemboursementAnticipe:
          json['peutRemboursementAnticipe'] as bool? ?? true,
      dateRemboursementAnticipe: parseOptionalDateTime(
        json['dateRemboursementAnticipe'],
      ),
      montantRemboursementAnticipe:
          (json['montantRemboursementAnticipe'] as num?)?.toDouble(),
      nouvelleDureeMois: (json['nouvelleDureeMois'] as num?)?.toInt(),
      parrainEmail: json['parrainEmail']?.toString(),
      emailsDisabled: json['emailsDisabled'] as bool? ?? false,
      penaltiesDisabled: json['penaltiesDisabled'] as bool? ?? false,
      reconnaissanceDetteUrl: json['reconnaissanceDetteUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'nomEmprunteur': nomEmprunteur,
      'ribEmprunteur': ribEmprunteur,
      'montant': montant,
      'dureeMois': dureeMois,
      'tauxBase': tauxBase,
      'coefficientDuree': coefficientDuree,
      'tauxAnnuel': tauxAnnuel,
      'mensualite': mensualite,
      'coutTotalEstime': coutTotalEstime,
      // 'objetPret': objetPret, // SUPPRIMÉ
      'dateSouhaitee': dateSouhaitee.toIso8601String(),
      'datePremierRemboursement': datePremierRemboursement.toIso8601String(),
      'statut': statut.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'disbursedAt': disbursedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'noteAdmin': noteAdmin,
      'referenceDecaissement': referenceDecaissement,
      'dateVirement': dateVirement?.toIso8601String(),
      'peutRemboursementAnticipe': peutRemboursementAnticipe,
      'dateRemboursementAnticipe': dateRemboursementAnticipe?.toIso8601String(),
      'montantRemboursementAnticipe': montantRemboursementAnticipe,
      'nouvelleDureeMois': nouvelleDureeMois,
      'parrainEmail': parrainEmail,
      'emailsDisabled': emailsDisabled,
      'penaltiesDisabled': penaltiesDisabled,
      'reconnaissanceDetteUrl': reconnaissanceDetteUrl,
    };
  }

  LoanModel copyWith({
    String? id,
    String? userId,
    String? nomEmprunteur,
    String? ribEmprunteur,
    double? montant,
    int? dureeMois,
    double? tauxBase,
    double? coefficientDuree,
    double? tauxAnnuel,
    double? mensualite,
    double? coutTotalEstime,
    // String? objetPret, // SUPPRIMÉ
    DateTime? dateSouhaitee,
    DateTime? datePremierRemboursement,
    LoanStatus? statut,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? disbursedAt,
    DateTime? updatedAt,
    String? noteAdmin,
    String? referenceDecaissement,
    DateTime? dateVirement,
    bool? peutRemboursementAnticipe,
    DateTime? dateRemboursementAnticipe,
    double? montantRemboursementAnticipe,
    int? nouvelleDureeMois,
    String? parrainEmail,
    bool? emailsDisabled,
    bool? penaltiesDisabled,
    String? reconnaissanceDetteUrl,
  }) {
    return LoanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nomEmprunteur: nomEmprunteur ?? this.nomEmprunteur,
      ribEmprunteur: ribEmprunteur ?? this.ribEmprunteur,
      montant: montant ?? this.montant,
      dureeMois: dureeMois ?? this.dureeMois,
      tauxBase: tauxBase ?? this.tauxBase,
      coefficientDuree: coefficientDuree ?? this.coefficientDuree,
      tauxAnnuel: tauxAnnuel ?? this.tauxAnnuel,
      mensualite: mensualite ?? this.mensualite,
      coutTotalEstime: coutTotalEstime ?? this.coutTotalEstime,
      // objetPret: objetPret ?? this.objetPret, // SUPPRIMÉ
      dateSouhaitee: dateSouhaitee ?? this.dateSouhaitee,
      datePremierRemboursement:
          datePremierRemboursement ?? this.datePremierRemboursement,
      statut: statut ?? this.statut,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      disbursedAt: disbursedAt ?? this.disbursedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      noteAdmin: noteAdmin ?? this.noteAdmin,
      referenceDecaissement:
          referenceDecaissement ?? this.referenceDecaissement,
      dateVirement: dateVirement ?? this.dateVirement,
      peutRemboursementAnticipe:
          peutRemboursementAnticipe ?? this.peutRemboursementAnticipe,
      dateRemboursementAnticipe:
          dateRemboursementAnticipe ?? this.dateRemboursementAnticipe,
      montantRemboursementAnticipe:
          montantRemboursementAnticipe ?? this.montantRemboursementAnticipe,
      nouvelleDureeMois: nouvelleDureeMois ?? this.nouvelleDureeMois,
      parrainEmail: parrainEmail ?? this.parrainEmail,
      emailsDisabled: emailsDisabled ?? this.emailsDisabled,
      penaltiesDisabled: penaltiesDisabled ?? this.penaltiesDisabled,
      reconnaissanceDetteUrl:
          reconnaissanceDetteUrl ?? this.reconnaissanceDetteUrl,
    );
  }

  bool get isActive => statut == LoanStatus.enCours;
  bool get isPending =>
      statut == LoanStatus.soumis || statut == LoanStatus.enRevue;
  bool get isApproved => statut == LoanStatus.approuve;
  bool get isCompleted =>
      statut == LoanStatus.solde || statut == LoanStatus.ferme;
  bool get isOverdue => statut == LoanStatus.enRetard;
  bool get isCancelled => statut == LoanStatus.annule;

  /// Vérifie si un prêt peut être annulé par l'emprunteur
  /// Un emprunteur ne peut annuler que les prêts non approuvés
  bool get canBeCancelledByBorrower =>
      statut == LoanStatus.brouillon ||
      statut == LoanStatus.soumis ||
      statut == LoanStatus.enRevue;

  /// Vérifie si un prêt peut être annulé par un admin
  /// Un admin peut annuler un prêt à tout moment sauf s'il est déjà terminé
  bool get canBeCancelledByAdmin =>
      statut != LoanStatus.solde &&
      statut != LoanStatus.annule &&
      statut != LoanStatus.ferme;

  /// Compatibilité avec l'ancien code - utilise la logique emprunteur par défaut
  bool get canBeCancelled => canBeCancelledByBorrower;

  /// Vérifie si le prêt permet le remboursement anticipé
  bool get allowsEarlyRepayment =>
      peutRemboursementAnticipe &&
      (statut == LoanStatus.enCours ||
          statut == LoanStatus.decaissementEffectue);

  /// Vérifie si un remboursement anticipé a été effectué
  bool get hasEarlyRepayment => dateRemboursementAnticipe != null;

  /// Obtient la durée effective du prêt (originale ou raccourcie)
  int get dureeEffective => nouvelleDureeMois ?? dureeMois;
}
