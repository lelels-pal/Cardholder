import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';

class SecureStorageService {
  static EncryptedSharedPreferences _getPrefs() {
    return EncryptedSharedPreferences();
  }

  static Future<void> setCredentials(String username, String password) async {
    final prefs = _getPrefs();
    await prefs.setString('traccar_username', username);
    await prefs.setString('traccar_password', password);
  }

  static Future<Map<String, String>> getCredentials() async {
    final prefs = _getPrefs();
    final username = await prefs.getString('traccar_username');
    final password = await prefs.getString('traccar_password');
    return {
      'username': username,
      'password': password,
    };
  }

  static Future<void> clearCredentials() async {
    final prefs = _getPrefs();
    await prefs.remove('traccar_username');
    await prefs.remove('traccar_password');
  }
}