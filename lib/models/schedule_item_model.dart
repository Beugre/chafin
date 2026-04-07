import 'package:json_annotation/json_annotation.dart';

part 'schedule_item_model.g.dart';

@JsonSerializable()
class ScheduleItemModel {
  final String id;
  final String loanId;
  final int numero;
  final DateTime dueDate;
  final double principal;
  final double interet;
  final double total;
  final bool isPaid;
  final DateTime? paidAt;
  final double? paidAmount;
  final String? noteAdmin;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool hasPenalty;
  final double? penaltyAmount;
  final double? originalTotal;
  final DateTime? penaltyAppliedAt;

  const ScheduleItemModel({
    required this.id,
    required this.loanId,
    required this.numero,
    required this.dueDate,
    required this.principal,
    required this.interet,
    required this.total,
    this.isPaid = false,
    this.paidAt,
    this.paidAmount,
    this.noteAdmin,
    required this.createdAt,
    this.updatedAt,
    this.hasPenalty = false,
    this.penaltyAmount,
    this.originalTotal,
    this.penaltyAppliedAt,
  });

  factory ScheduleItemModel.fromJson(Map<String, dynamic> json) =>
      _$ScheduleItemModelFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleItemModelToJson(this);

  ScheduleItemModel copyWith({
    String? id,
    String? loanId,
    int? numero,
    DateTime? dueDate,
    double? principal,
    double? interet,
    double? total,
    bool? isPaid,
    DateTime? paidAt,
    double? paidAmount,
    String? noteAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasPenalty,
    double? penaltyAmount,
    double? originalTotal,
    DateTime? penaltyAppliedAt,
  }) {
    return ScheduleItemModel(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      numero: numero ?? this.numero,
      dueDate: dueDate ?? this.dueDate,
      principal: principal ?? this.principal,
      interet: interet ?? this.interet,
      total: total ?? this.total,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      paidAmount: paidAmount ?? this.paidAmount,
      noteAdmin: noteAdmin ?? this.noteAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasPenalty: hasPenalty ?? this.hasPenalty,
      penaltyAmount: penaltyAmount ?? this.penaltyAmount,
      originalTotal: originalTotal ?? this.originalTotal,
      penaltyAppliedAt: penaltyAppliedAt ?? this.penaltyAppliedAt,
    );
  }

  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);
  int get daysOverdue =>
      isOverdue ? DateTime.now().difference(dueDate).inDays : 0;

  /// Montant effectif de la pénalité (0 si pas de pénalité)
  double get effectivePenalty => penaltyAmount ?? 0.0;
}
