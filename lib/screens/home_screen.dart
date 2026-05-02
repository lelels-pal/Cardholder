import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform; // Add import
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // Add import
import '../constants.dart';
import '../services/tracker_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/top_notification_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  // Traccar Credentials
  TrackerService? _trackerService;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _buzzerOn = false;
  Timer? _timer;
  Map<String, double>? _currentLocation;
  String? _error;
  DateTime? _lastUpdateTime;

  // Anti-Loss State
  bool _antiLossEnabled = false;
  double? _distance;
  final double _maxDistanceThreshold = 50.0; // meters
  int _consecutiveFarReadings = 0; // Debounce counter
  Position? _lastUserPosition; // For debug display

  // Default center if no location found yet (Ayala Ave)
  final LatLng _defaultCenter = const LatLng(14.5547, 121.0244);

  // Hardcoded deviceIMEI for now as per previous implementation
  final String _deviceImei = '359339078106061';

  @override
  void initState() {
    super.initState();
    _checkLocationPermission(); // Check permission on start
    _initTracker();
  }

  Future<void> _initTracker() async {
    try {
      final creds = await SecureStorageService.getCredentials();
      if (mounted) {
        setState(() {
          _trackerService = TrackerService(
            username: creds['username']!,
            password: creds['password']!,
          );
        });
        _startLocationUpdates();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load credentials: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _trackerService?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _startLocationUpdates() {
    _fetchLocation();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchLocation(),
    );
  }

  Future<void> _fetchLocation({bool recenterMap = false}) async {
    if (_isRefreshing) return;

    if (recenterMap) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      if (_trackerService == null) return;
      final position = await _trackerService!.getDevicePosition(_deviceImei);

      if (mounted) {
        final bool isFirstLoad = _currentLocation == null;

        Position? userPosition;
        if (_antiLossEnabled) {
          try {
            userPosition = await Geolocator.getCurrentPosition();
          } catch (e) {
            debugPrint('Error getting user location: $e');
          }
        }

        // Validate Coordinates BEFORE updating state
        // Filter out "Null Island" (0,0)
        if (position['lat'] == 0.0 && position['lng'] == 0.0) {
          debugPrint('Ignoring (0,0) coordinates from tracker');
          return;
        }

        if (userPosition != null &&
            (userPosition.latitude == 0.0 && userPosition.longitude == 0.0)) {
          debugPrint('Ignoring (0,0) coordinates from phone');
          return;
        }

        setState(() {
          _currentLocation = position;
          _lastUserPosition = userPosition; // Store for debug display
          _lastUpdateTime = DateTime.now();
          _error = null;

          if (userPosition != null &&
              position['lat'] != null &&
              position['lng'] != null) {
            final Distance distance = const Distance();
            _distance = distance.as(
              LengthUnit.Meter,
              LatLng(userPosition.latitude, userPosition.longitude),
              LatLng(position['lat']!, position['lng']!),
            );

            if (_distance! > _maxDistanceThreshold) {
              _consecutiveFarReadings++;
              // Only alert if we have 3 consecutive readings (approx 15 seconds)
              if (_consecutiveFarReadings >= 3) {
                // Cap the counter so it doesn't grow indefinitely
                _consecutiveFarReadings = 3;

                TopNotificationModal.show(
                  context,
                  message: '⚠️ Alert: Device is too far away!',
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                  icon: Icons.warning,
                );
              }
            } else {
              // Reset counter if back in range
              _consecutiveFarReadings = 0;
            }
          }
        });

        if ((isFirstLoad || recenterMap) &&
            position['lat'] != null &&
            position['lng'] != null) {
          _mapController.move(LatLng(position['lat']!, position['lng']!), 15.0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted && recenterMap) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _sendBuzzerCommand(bool turnOn) async {
    setState(() {
      _isLoading = true;
    });

    final String hexCommand = turnOn ? '78780249010D0A' : '78780249000D0A';
    final String action = turnOn ? 'activated' : 'deactivated';

    try {
      if (_trackerService == null) throw Exception('Tracker not initialized');
      
      // Check connection status before sending
      if (_getGpsStatusText() == 'Disconnected') {
        throw Exception('Cannot send command: Device is disconnected');
      }

      await _trackerService!.sendHexCommand(_deviceImei, hexCommand);

      if (!mounted) return;
      setState(() {
        _buzzerOn = turnOn;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Buzzer $action successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send command: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMaps() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for device location...')),
      );
      return;
    }

    final lat = _currentLocation!['lat'];
    final lng = _currentLocation!['lng'];

    // Google Maps URL (works on iOS and Android if installed, falls back to browser)
    // Using query parameter 'q' for a pin at the location
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    // Apple Maps URL (specific for iOS native experience)
    final Uri appleMapsUrl = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lng',
    );

    try {
      if (Platform.isIOS) {
        // Force Apple Maps on iOS
        if (await canLaunchUrl(appleMapsUrl)) {
          await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to Google Maps if Apple Maps somehow fails
          if (await canLaunchUrl(googleMapsUrl)) {
            await launchUrl(
              googleMapsUrl,
              mode: LaunchMode.externalApplication,
            );
          }
        }
      } else {
        // Android / Other: Try Google Maps
        if (await canLaunchUrl(googleMapsUrl)) {
          await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch maps';
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch maps: $e')));
    }
  }

  // Helper methods for GPS status
  String _getGpsStatusText() {
    if (_error != null) {
      return 'Error';
    }
    if (_currentLocation == null) {
      return 'Searching...';
    }
    if (_lastUpdateTime != null) {
      final difference = DateTime.now().difference(_lastUpdateTime!);
      if (difference.inSeconds < 120) {
        return 'Connected';
      } else {
        return 'Disconnected';
      }
    }
    return 'Connected';
  }

  Color _getGpsStatusColor() {
    if (_error != null) {
      return Colors.red;
    }
    if (_currentLocation == null) {
      return Colors.grey;
    }
    if (_lastUpdateTime != null) {
      final difference = DateTime.now().difference(_lastUpdateTime!);
      if (difference.inSeconds < 120) {
        return AppColors.primary;
      } else {
        return Colors.orange;
      }
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    // Determine map center and marker position
    LatLng displayCenter = _defaultCenter;
    double? accuracy;

    if (_currentLocation != null) {
      displayCenter = LatLng(
        _currentLocation!['lat']!,
        _currentLocation!['lng']!,
      );
      accuracy = _currentLocation!['accuracy'];
    }

    return SafeArea(
      child: Column(
        children: [
          // Anti-Loss Mode Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Anti-Loss Icon and Text
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.security,
                    color: _antiLossEnabled
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ANTI-LOSS MODE',
                    style: TextStyle(
                      color: _antiLossEnabled
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                // Distance Display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Distance:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      _distance != null && _antiLossEnabled
                          ? (_distance! >= 1000
                                ? '${(_distance! / 1000).toStringAsFixed(1)}km'
                                : '${_distance!.toStringAsFixed(0)}m')
                          : '--',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Anti-Loss Toggle
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _antiLossEnabled,
                    onChanged: (value) {
                      setState(() {
                        _antiLossEnabled = value;
                        if (!value) {
                          _distance = null;
                        }
                      });
                    },
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Debug Info (only shown when anti-loss enabled and data available)
          if (_antiLossEnabled &&
              _currentLocation != null &&
              _lastUserPosition != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(
                'DEBUG: Phone: ${_lastUserPosition!.latitude.toStringAsFixed(5)}, ${_lastUserPosition!.longitude.toStringAsFixed(5)} | Tracker: ${_currentLocation!['lat']?.toStringAsFixed(5)}, ${_currentLocation!['lng']?.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 8,
                  fontFamily: 'monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Map Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: displayCenter,
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.sentra.app',
                        ),
                        if (_currentLocation != null) ...[
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: displayCenter,
                                radius: accuracy ?? 100,
                                useRadiusInMeter: true,
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderColor: AppColors.primary,
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: displayCenter,
                                width: 60,
                                height: 60,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 3,
                                    ),
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.my_location,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Location Status Overlay
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground.withValues(
                            alpha: 0.95,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _error != null
                              ? 'Error connecting'
                              : (_currentLocation != null
                                    ? 'Location Found'
                                    : 'Searching...'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Refresh Button
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: _isRefreshing
                            ? null
                            : () => _fetchLocation(recenterMap: true),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground.withValues(
                              alpha: 0.95,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isRefreshing
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh,
                                  color: AppColors.primary,
                                  size: 26,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Status Cards Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Module Battery Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.battery_full,
                            color: _currentLocation != null && _getGpsStatusText() != 'Disconnected'
                                ? (_currentLocation!['batteryLevel']! > 20
                                      ? AppColors.primary
                                      : Colors.red)
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Module Battery',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentLocation != null && _getGpsStatusText() != 'Disconnected'
                                    ? '${_currentLocation!['batteryLevel']?.toStringAsFixed(1)}%'
                                    : '...',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // LTE Signal Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.signal_cellular_alt,
                            color: _currentLocation != null && _getGpsStatusText() != 'Disconnected'
                                ? (_currentLocation!['rssi']! > -100
                                      ? Colors.blue
                                      : Colors.orange)
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'LTE Signal',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentLocation != null && _getGpsStatusText() != 'Disconnected'
                                    ? '${_currentLocation!['rssi']!.toInt()} dBm'
                                    : 'N/A',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Navigate Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _currentLocation == null || _getGpsStatusText() == 'Disconnected' ? null : _openMaps,
                icon: const Icon(Icons.diamond, color: Colors.white, size: 18),
                label: const Text(
                  'NAVIGATE TO DEVICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Alarm and GPS Status Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Alarm Toggle
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: _buzzerOn
                            ? LinearGradient(
                                colors: [
                                  Colors.red.withValues(alpha: 0.8),
                                  Colors.redAccent.withValues(alpha: 0.6),
                                ],
                              )
                            : null,
                        color: _buzzerOn ? null : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _buzzerOn
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.volume_up,
                              color: _buzzerOn ? Colors.white : Colors.red,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'ALARM',
                              style: TextStyle(
                                color: _buzzerOn
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _buzzerOn,
                              onChanged: _isLoading || _getGpsStatusText() == 'Disconnected'
                                  ? null
                                  : (value) => _sendBuzzerCommand(value),
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppColors.primary,
                              inactiveThumbColor: AppColors.textSecondary,
                              inactiveTrackColor: AppColors.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // GPS Status
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getGpsStatusColor().withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.gps_fixed,
                              color: _getGpsStatusColor(),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'GPS STATUS',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getGpsStatusText(),
                                  style: TextStyle(
                                    color: _getGpsStatusColor(),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
