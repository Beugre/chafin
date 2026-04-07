import 'package:json_annotation/json_annotation.dart';

part 'notification_model.g.dart';

/// Modèle pour les notifications dans l'application
@JsonSerializable()
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  /// Crée une instance depuis JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  /// Convertit en JSON
  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  /// Copie avec modifications
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  /// Marque comme lue
  NotificationModel markAsRead() {
    return copyWith(isRead: true);
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, type: $type, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Types de notifications
@JsonEnum()
enum NotificationType {
  @JsonValue('loan_requested')
  loanRequested,

  @JsonValue('loan_approved')
  loanApproved,

  @JsonValue('loan_rejected')
  loanRejected,

  @JsonValue('payment_due')
  paymentDue,

  @JsonValue('payment_overdue')
  paymentOverdue,

  @JsonValue('payment_received')
  paymentReceived,

  @JsonValue('loan_completed')
  loanCompleted,

  @JsonValue('system')
  system,

  @JsonValue('general')
  general,

  @JsonValue('rate_change')
  rateChange;

  /// Obtient l'icône correspondante au type
  String get icon {
    switch (this) {
      case NotificationType.loanRequested:
        return '📋';
      case NotificationType.loanApproved:
        return '✅';
      case NotificationType.loanRejected:
        return '❌';
      case NotificationType.paymentDue:
        return '⏰';
      case NotificationType.paymentOverdue:
        return '⚠️';
      case NotificationType.paymentReceived:
        return '💰';
      case NotificationType.loanCompleted:
        return '🎉';
      case NotificationType.system:
        return '🔧';
      case NotificationType.general:
        return '📢';
      case NotificationType.rateChange:
        return '📊';
    }
  }

  /// Obtient la couleur correspondante au type
  String get colorHex {
    switch (this) {
      case NotificationType.loanRequested:
        return '#2196F3';
      case NotificationType.loanApproved:
        return '#4CAF50';
      case NotificationType.loanRejected:
        return '#F44336';
      case NotificationType.paymentDue:
        return '#FF9800';
      case NotificationType.paymentOverdue:
        return '#F44336';
      case NotificationType.paymentReceived:
        return '#4CAF50';
      case NotificationType.loanCompleted:
        return '#9C27B0';
      case NotificationType.system:
        return '#607D8B';
      case NotificationType.general:
        return '#9E9E9E';
      case NotificationType.rateChange:
        return '#00BCD4';
    }
  }
}
