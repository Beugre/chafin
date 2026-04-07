enum PaymentStatus { aVenir, echue, payee, enRetard, reportee }

class PaymentScheduleItem {
  final int numeroEcheance;
  final DateTime dateEcheance;
  final double montantCapital;
  final double montantInterets;
  final double montantTotal;
  final double capitalRestantDu;
  final PaymentStatus statut;
  final DateTime? datePaiement;
  final double? montantPaye;
  final String? notePaiement;

  const PaymentScheduleItem({
    required this.numeroEcheance,
    required this.dateEcheance,
    required this.montantCapital,
    required this.montantInterets,
    required this.montantTotal,
    required this.capitalRestantDu,
    this.statut = PaymentStatus.aVenir,
    this.datePaiement,
    this.montantPaye,
    this.notePaiement,
  });

  PaymentScheduleItem copyWith({
    int? numeroEcheance,
    DateTime? dateEcheance,
    double? montantCapital,
    double? montantInterets,
    double? montantTotal,
    double? capitalRestantDu,
    PaymentStatus? statut,
    DateTime? datePaiement,
    double? montantPaye,
    String? notePaiement,
  }) {
    return PaymentScheduleItem(
      numeroEcheance: numeroEcheance ?? this.numeroEcheance,
      dateEcheance: dateEcheance ?? this.dateEcheance,
      montantCapital: montantCapital ?? this.montantCapital,
      montantInterets: montantInterets ?? this.montantInterets,
      montantTotal: montantTotal ?? this.montantTotal,
      capitalRestantDu: capitalRestantDu ?? this.capitalRestantDu,
      statut: statut ?? this.statut,
      datePaiement: datePaiement ?? this.datePaiement,
      montantPaye: montantPaye ?? this.montantPaye,
      notePaiement: notePaiement ?? this.notePaiement,
    );
  }

  bool get isOverdue {
    if (statut == PaymentStatus.payee) return false;
    return DateTime.now().isAfter(dateEcheance);
  }

  bool get isPaid => statut == PaymentStatus.payee;
}

class PaymentSchedule {
  final String loanId;
  final List<PaymentScheduleItem> echeances;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PaymentSchedule({
    required this.loanId,
    required this.echeances,
    required this.createdAt,
    this.updatedAt,
  });

  double get totalCapital =>
      echeances.fold(0.0, (sum, item) => sum + item.montantCapital);

  double get totalInterets =>
      echeances.fold(0.0, (sum, item) => sum + item.montantInterets);

  double get totalMontant => totalCapital + totalInterets;

  double get montantPaye => echeances
      .where((item) => item.isPaid)
      .fold(0.0, (sum, item) => sum + (item.montantPaye ?? item.montantTotal));

  double get montantRestant => totalMontant - montantPaye;

  int get nombreEcheancesPayees =>
      echeances.where((item) => item.isPaid).length;

  int get nombreEcheancesEnRetard =>
      echeances.where((item) => item.isOverdue && !item.isPaid).length;

  PaymentScheduleItem? get prochaineEcheance => echeances
      .where((item) => !item.isPaid)
      .fold<PaymentScheduleItem?>(null, (earliest, item) {
        if (earliest == null ||
            item.dateEcheance.isBefore(earliest.dateEcheance)) {
          return item;
        }
        return earliest;
      });
}
