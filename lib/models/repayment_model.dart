// Modèle de remboursement/mensualité

enum RepaymentStatus { enAttente, paye, enRetard, annule }

class RepaymentModel {
  final String id;
  final String loanId;
  final String userId;
  final int numeroMensualite; // 1, 2, 3...
  final double montantDu;
  final double montantPaye;
  final DateTime dateEcheance;
  final DateTime? datePaiement;
  final RepaymentStatus statut;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? noteAdmin;
  final String? referencePaiement;

  const RepaymentModel({
    required this.id,
    required this.loanId,
    required this.userId,
    required this.numeroMensualite,
    required this.montantDu,
    this.montantPaye = 0.0,
    required this.dateEcheance,
    this.datePaiement,
    this.statut = RepaymentStatus.enAttente,
    required this.createdAt,
    this.updatedAt,
    this.noteAdmin,
    this.referencePaiement,
  });

  factory RepaymentModel.fromJson(Map<String, dynamic> json) {
    RepaymentStatus parseStatus(dynamic statusValue) {
      if (statusValue is String) {
        switch (statusValue) {
          case 'enAttente':
            return RepaymentStatus.enAttente;
          case 'paye':
            return RepaymentStatus.paye;
          case 'enRetard':
            return RepaymentStatus.enRetard;
          case 'annule':
            return RepaymentStatus.annule;
          default:
            return RepaymentStatus.enAttente;
        }
      }
      return RepaymentStatus.enAttente;
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

    return RepaymentModel(
      id: json['id']?.toString() ?? '',
      loanId: json['loanId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      numeroMensualite: (json['numeroMensualite'] as num?)?.toInt() ?? 0,
      montantDu: (json['montantDu'] as num?)?.toDouble() ?? 0.0,
      montantPaye: (json['montantPaye'] as num?)?.toDouble() ?? 0.0,
      dateEcheance: parseDateTime(json['dateEcheance']),
      datePaiement: parseOptionalDateTime(json['datePaiement']),
      statut: parseStatus(json['statut']),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseOptionalDateTime(json['updatedAt']),
      noteAdmin: json['noteAdmin']?.toString(),
      referencePaiement: json['referencePaiement']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loanId': loanId,
      'userId': userId,
      'numeroMensualite': numeroMensualite,
      'montantDu': montantDu,
      'montantPaye': montantPaye,
      'dateEcheance': dateEcheance.toIso8601String(),
      'datePaiement': datePaiement?.toIso8601String(),
      'statut': statut.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'noteAdmin': noteAdmin,
      'referencePaiement': referencePaiement,
    };
  }

  RepaymentModel copyWith({
    String? id,
    String? loanId,
    String? userId,
    int? numeroMensualite,
    double? montantDu,
    double? montantPaye,
    DateTime? dateEcheance,
    DateTime? datePaiement,
    RepaymentStatus? statut,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? noteAdmin,
    String? referencePaiement,
  }) {
    return RepaymentModel(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      userId: userId ?? this.userId,
      numeroMensualite: numeroMensualite ?? this.numeroMensualite,
      montantDu: montantDu ?? this.montantDu,
      montantPaye: montantPaye ?? this.montantPaye,
      dateEcheance: dateEcheance ?? this.dateEcheance,
      datePaiement: datePaiement ?? this.datePaiement,
      statut: statut ?? this.statut,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      noteAdmin: noteAdmin ?? this.noteAdmin,
      referencePaiement: referencePaiement ?? this.referencePaiement,
    );
  }

  bool get isPaid => statut == RepaymentStatus.paye;
  bool get isOverdue => statut == RepaymentStatus.enRetard;
  bool get isPending => statut == RepaymentStatus.enAttente;

  double get montantRestant => montantDu - montantPaye;
  bool get isFullyPaid => montantPaye >= montantDu;
}
