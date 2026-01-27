import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service class for communicating with the Traccar API.
///
/// Traccar API Documentation: https://www.traccar.org/api-reference/
///
/// This service provides methods to:
/// - Get internal device ID from IMEI
/// - Send hex commands to devices
class TrackerService {
  /// Traccar server base URL
  static const String _baseUrl = 'https://demo3.traccar.org';

  /// HTTP client for making requests (allows for testing/mocking)
  final http.Client _client;

  /// Authorization header value (Base64 encoded credentials)
  final String _authHeader;

  /// Creates a TrackerService instance.
  ///
  /// [username] - Traccar account username
  /// [password] - Traccar account password
  /// [client] - Optional HTTP client for testing
  TrackerService({
    required String username,
    required String password,
    http.Client? client,
  }) : _authHeader =
           'Basic ${base64Encode(utf8.encode('$username:$password'))}',
       _client = client ?? http.Client();

  /// Standard headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': _authHeader,
  };

  /// Gets the internal Traccar device ID from an IMEI.
  ///
  /// The Traccar API requires an internal database ID to send commands,
  /// not the device's IMEI. This method resolves the IMEI to the internal ID.
  ///
  /// [imei] - The device's IMEI/uniqueId
  ///
  /// Returns the internal device ID.
  ///
  /// Throws [TraccarException] if the device is not found or on API error.
  Future<int> getDeviceId(String imei) async {
    final uri = Uri.parse(
      '$_baseUrl/api/devices',
    ).replace(queryParameters: {'uniqueId': imei});

    try {
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> devices = jsonDecode(response.body);

        if (devices.isEmpty) {
          throw TraccarException(
            'Device not found with IMEI: $imei',
            statusCode: 404,
          );
        }

        // Return the first matching device's ID
        final deviceId = devices[0]['id'] as int;
        return deviceId;
      } else if (response.statusCode == 401) {
        throw TraccarException(
          'Authentication failed. Check username/password.',
          statusCode: 401,
        );
      } else {
        throw TraccarException(
          'Failed to get device: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on TraccarException {
      rethrow;
    } catch (e) {
      throw TraccarException('Network error: $e');
    }
  }

  /// Sends a hex command to a device.
  ///
  /// This method first resolves the IMEI to an internal device ID,
  /// then sends the command to the Traccar API.
  ///
  /// [imei] - The device's IMEI/uniqueId
  /// [hex] - The hex command string to send
  ///
  /// Returns `true` if the command was sent successfully.
  ///
  /// Throws [TraccarException] on any error.
  Future<bool> sendHexCommand(String imei, String hex) async {
    // First, resolve the IMEI to internal device ID
    final deviceId = await getDeviceId(imei);

    final uri = Uri.parse('$_baseUrl/api/commands/send');

    final body = jsonEncode({
      'deviceId': deviceId,
      'type': 'custom',
      'attributes': {'data': hex},
    });

    try {
      final response = await _client.post(uri, headers: _headers, body: body);

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw TraccarException(
          'Authentication failed. Check username/password.',
          statusCode: 401,
        );
      } else if (response.statusCode == 400) {
        throw TraccarException(
          'Bad request: ${response.body}',
          statusCode: 400,
        );
      } else {
        throw TraccarException(
          'Failed to send command: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on TraccarException {
      rethrow;
    } catch (e) {
      throw TraccarException('Network error: $e');
    }
  }

  /// Gets the current position of a device.
  ///
  /// [imei] - The device's IMEI/uniqueId
  ///
  /// Returns a Map containing 'lat', 'lng', 'accuracy', 'batteryLevel', and 'rssi'.
  Future<Map<String, double>> getDevicePosition(String imei) async {
    final deviceId = await getDeviceId(imei);
    final uri = Uri.parse(
      '$_baseUrl/api/positions',
    ).replace(queryParameters: {'deviceId': deviceId.toString()});

    try {
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> positions = jsonDecode(response.body);

        if (positions.isEmpty) {
          throw TraccarException(
            'No position data found for device: $imei',
            statusCode: 404,
          );
        }

        // Traccar returns a list of positions, usually the latest one first or just one
        // We take the last one in the list which is typically the most recent in Traccar API responses for specific device queries
        // Actually, /api/positions?deviceId=X returns the latest position(s).
        final latestPosition = positions.last;
        print('DEBUG ATTRIBUTES: ${latestPosition['attributes']}');

        return {
          'lat': (latestPosition['latitude'] as num).toDouble(),
          'lng': (latestPosition['longitude'] as num).toDouble(),
          'accuracy': (latestPosition['accuracy'] as num).toDouble(),
          // Traccar usually puts these in 'attributes'
          'batteryLevel':
              (latestPosition['attributes']?['batteryLevel'] ??
                      latestPosition['attributes']?['battery'] ??
                      latestPosition['attributes']?['power'] ??
                      latestPosition['attributes']?['level'] ??
                      0)
                  .toDouble(),
          'rssi':
              (latestPosition['attributes']?['rssi'] ??
                      latestPosition['attributes']?['io3'] ??
                      0)
                  .toDouble(), // io3 is often SSI in some protocols
        };
      } else if (response.statusCode == 401) {
        throw TraccarException(
          'Authentication failed. Check username/password.',
          statusCode: 401,
        );
      } else {
        throw TraccarException(
          'Failed to get position: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on TraccarException {
      rethrow;
    } catch (e) {
      throw TraccarException('Network error: $e');
    }
  }

  /// Disposes of the HTTP client.
  ///
  /// Call this when the service is no longer needed.
  void dispose() {
    _client.close();
  }
}

/// Exception thrown by TrackerService operations.
class TraccarException implements Exception {
  /// Error message
  final String message;

  /// HTTP status code, if applicable
  final int? statusCode;

  TraccarException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode != null) {
      return 'TraccarException [$statusCode]: $message';
    }
    return 'TraccarException: $message';
  }
}
