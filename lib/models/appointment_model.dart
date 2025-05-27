enum AppointmentStatus {
  pending,
  accepted,
  approved,
  denied,
  confirmed,
  completed,
  cancelled,
  archived,
}

class AppointmentModel {
  final String id;
  final String psychologistId;
  final String userId;
  final DateTime appointmentDate;
  final String reason;
  final AppointmentStatus status;
  final String? responseMessage;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.psychologistId,
    required this.userId,
    required this.appointmentDate,
    required this.reason,
    required this.status,
    this.responseMessage,
    required this.createdAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    // Parse status from string
    AppointmentStatus parseStatus(String statusStr) {
      switch (statusStr.toLowerCase()) {
        case 'pending':
          return AppointmentStatus.pending;
        case 'accepted':
          return AppointmentStatus.accepted;
        case 'approved':
          return AppointmentStatus.approved;
        case 'denied':
          return AppointmentStatus.denied;
        case 'confirmed':
          return AppointmentStatus.confirmed;
        case 'completed':
          return AppointmentStatus.completed;
        case 'cancelled':
          return AppointmentStatus.cancelled;
        case 'archived':
          return AppointmentStatus.archived;
        default:
          return AppointmentStatus.pending;
      }
    }

    return AppointmentModel(
      id: json['id'] ?? 'unknown',
      psychologistId: json['psychologist_id'] ?? 'unknown',
      userId: json['user_id'] ?? 'unknown',
      appointmentDate: DateTime.parse(json['appointment_date']),
      reason: json['reason'] ?? 'No reason provided',
      status: parseStatus(json['status'] ?? 'pending'),
      responseMessage: json['response_message'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'psychologist_id': psychologistId,
      'user_id': userId,
      'appointment_date': appointmentDate.toIso8601String(),
      'reason': reason,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      if (responseMessage != null) 'response_message': responseMessage,
    };
  }

  String get statusText {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.accepted:
        return 'Accepted';
      case AppointmentStatus.approved:
        return 'Approved';
      case AppointmentStatus.denied:
        return 'Denied';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.archived:
        return 'Archived';
    }
  }
}
