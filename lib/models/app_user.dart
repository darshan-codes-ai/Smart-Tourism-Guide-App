class AppUser {
  const AppUser({
    required this.uid,
    this.name,
    this.email,
    this.photoUrl,
    this.phoneNumber,
    required this.provider,
    this.role = 'user',
  });

  final String uid;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String? phoneNumber;
  final String provider;
  final String role;

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? provider,
    String? role,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      provider: provider ?? this.provider,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'provider': provider,
      'role': role,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      provider: map['provider'] as String? ?? 'password',
      role: map['role'] as String? ?? 'user',
    );
  }
}
