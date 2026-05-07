

/// Unified configuration service for Traccar credentials.
///
/// We now use the main app login credentials for Traccar as well,
/// removing the need for the user to configure Traccar separately.
class ConfigService {
  /// Gets the Traccar credentials (hardcoded for shared Traccar account).
  static Future<Map<String, String>> getTraccarConfig() async {
    return {
      'username': 'pallorinaleoangelo@gmail.com',
      'password': 'cardikeep',
    };
  }

  /// Checks whether credentials have been configured (i.e. user is logged in).
  static Future<bool> hasTraccarConfig() async {
    final creds = await getTraccarConfig();
    return (creds['username'] ?? '').isNotEmpty && (creds['password'] ?? '').isNotEmpty;
  }
}