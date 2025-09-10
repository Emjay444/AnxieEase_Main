class PsychologistModel {
  final String id;
  final String name;
  final String specialization;
  final String contactEmail;
  final String contactPhone;
  final String biography;
  final String? imageUrl;

  PsychologistModel({
    required this.id,
    required this.name,
    required this.specialization,
    required this.contactEmail,
    required this.contactPhone,
    required this.biography,
    this.imageUrl,
  });

  factory PsychologistModel.fromJson(Map<String, dynamic> json) {
    return PsychologistModel(
      id: json['id'] ?? 'unknown-id',
      name: json['name'] ?? 'Unknown Psychologist',
      specialization: json['specialization'] ?? 'General Psychology',
    // Prefer explicit contact_email; fall back to generic email or last resort placeholder
    contactEmail: (json['contact_email'] ?? json['email'] ?? '').isNotEmpty
      ? (json['contact_email'] ?? json['email'])
      : 'contact@anxiease.com',
      contactPhone: json['contact_phone'] ?? 'N/A',
      biography: json['biography'] ?? 'No biography available',
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'biography': biography,
      'image_url': imageUrl,
    };
  }

  // Get initials from name (e.g., "John Doe" -> "JD")
  String get initials {
    final nameParts = name.split(' ').where((part) => part.isNotEmpty).toList();

    if (nameParts.length >= 2) {
      // Get first letter of first and last name
      return nameParts.first[0] + nameParts.last[0];
    } else if (nameParts.isNotEmpty) {
      // If only one name, use the first letter
      return nameParts.first[0];
    } else {
      // Fallback if name is empty
      return '?';
    }
  }
}
