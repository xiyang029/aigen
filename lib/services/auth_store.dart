import 'package:shared_preferences/shared_preferences.dart';

class SavedLogin {
  const SavedLogin({required this.email, required this.password});

  final String email;
  final String password;
}

class AuthStore {
  static const _tokenKey = 'app_auth_token';
  static const _baseUrlKey = 'worker_base_url';
  static const _emailKey = 'app_login_email';
  static const _passwordKey = 'app_login_password';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<String?> readBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey);
  }

  Future<void> saveBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, value);
  }

  Future<SavedLogin?> readLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey) ?? '';
    final password = prefs.getString(_passwordKey) ?? '';
    if (email.isEmpty && password.isEmpty) return null;
    return SavedLogin(email: email, password: password);
  }

  Future<void> saveLogin({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_passwordKey, password);
  }
}

