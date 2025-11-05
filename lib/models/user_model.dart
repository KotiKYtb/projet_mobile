class UserModel {
  final int? id;
  final int userId;
  final String email;
  final String name;
  final String surname;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSync;

  UserModel({
    this.id,
    required this.userId,
    required this.email,
    required this.name,
    required this.surname,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.lastSync,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'email': email,
      'name': name,
      'surname': surname,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_sync': lastSync?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      userId: map['user_id'],
      email: map['email'],
      name: map['name'],
      surname: map['surname'],
      role: map['role'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      lastSync: map['last_sync'] != null ? DateTime.parse(map['last_sync']) : null,
    );
  }

  factory UserModel.fromApi(Map<String, dynamic> apiData) {
    return UserModel(
      userId: apiData['user_id'],
      email: apiData['email'],
      name: apiData['name'] ?? '',
      surname: apiData['surname'] ?? '',
      role: apiData['role'] ?? 'user',
      createdAt: DateTime.parse(apiData['created_at']),
      updatedAt: DateTime.parse(apiData['updated_at']),
      lastSync: DateTime.now(),
    );
  }

  UserModel copyWith({
    int? id,
    int? userId,
    String? email,
    String? name,
    String? surname,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSync,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}
