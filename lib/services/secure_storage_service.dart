import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';

class SecureStorageService {
  static EncryptedSharedPreferences _getPrefs() {
    return EncryptedSharedPreferences();
  }

  // ─── App Login Credentials (local auth only) ──────────────────────────────

  static Future<void> setCredentials(String username, String password) async {
    final prefs = _getPrefs();
    await prefs.setString('app_username', username);
    await prefs.setString('app_password', password);
  }

  static Future<Map<String, String>> getCredentials() async {
    final prefs = _getPrefs();
    final username = await prefs.getString('app_username');
    final password = await prefs.getString('app_password');
    return {
      'username': username,
      'password': password,
    };
  }

  static Future<void> clearCredentials() async {
    final prefs = _getPrefs();
    await prefs.remove('app_username');
    await prefs.remove('app_password');
  }

  // ─── Traccar API Credentials (for tracker server authentication) ──────────

  static Future<void> setTraccarCredentials(
    String username,
    String password,
  ) async {
    final prefs = _getPrefs();
    await prefs.setString('traccar_username', username);
    await prefs.setString('traccar_password', password);
  }

  static Future<Map<String, String>> getTraccarCredentials() async {
    final prefs = _getPrefs();
    final username = await prefs.getString('traccar_username');
    final password = await prefs.getString('traccar_password');
    return {
      'username': username,
      'password': password,
    };
  }

  static Future<bool> hasTraccarCredentials() async {
    final creds = await getTraccarCredentials();
    return (creds['username']?.isNotEmpty ?? false) &&
        (creds['password']?.isNotEmpty ?? false);
  }

  static Future<void> clearTraccarCredentials() async {
    final prefs = _getPrefs();
    await prefs.remove('traccar_username');
    await prefs.remove('traccar_password');
  }
}