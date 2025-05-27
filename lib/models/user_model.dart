class UserModel {
  final String id;
  final String email;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final int? age;
  final String? contactNumber;
  final String? gender;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.middleName,
    this.lastName,
    this.age,
    this.contactNumber,
    this.gender,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      age: json['age'],
      contactNumber: json['contact_number'],
      gender: json['gender'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'age': age,
      'contact_number': contactNumber,
      'gender': gender,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? middleName,
    String? lastName,
    int? age,
    String? contactNumber,
    String? gender,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      age: age ?? this.age,
      contactNumber: contactNumber ?? this.contactNumber,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to get full name
  String? get fullName {
    final names = [
      if (firstName != null) firstName,
      if (middleName != null) middleName,
      if (lastName != null) lastName,
    ];
    return names.isNotEmpty ? names.join(' ') : null;
  }
}
