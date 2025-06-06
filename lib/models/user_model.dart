class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final DateTime? birthDate;
  final String? gender;
  final String? contactNumber;
  final String? emergencyContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.birthDate,
    this.gender,
    this.contactNumber,
    this.emergencyContact,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculate age based on birth date
  int? get age {
    if (birthDate == null) return null;

    final today = DateTime.now();
    int age = today.year - birthDate!.year;

    // Adjust age if birthday hasn't occurred yet this year
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      age--;
    }

    return age;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      gender: json['gender'],
      contactNumber: json['contact_number'],
      emergencyContact: json['emergency_contact'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'contact_number': contactNumber,
      'emergency_contact': emergencyContact,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? birthDate,
    String? gender,
    String? contactNumber,
    String? emergencyContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      contactNumber: contactNumber ?? this.contactNumber,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
