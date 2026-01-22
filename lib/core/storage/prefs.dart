import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _backendUrlKey = 'backend_url';
  static const _usernameKey = 'username';
  static const _uuidKey = 'user_uuid';
  static const _passwordKey = 'user_password';

  static Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url);
  }

  static Future<String?> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendUrlKey);
  }

  static Future<void> setUser(String username, String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_uuidKey, uuid);
  }

  static Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, password);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_uuidKey);
  }

  static Future<String?> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
