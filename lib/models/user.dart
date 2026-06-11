class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}

