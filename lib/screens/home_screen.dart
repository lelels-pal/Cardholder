import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform; // Add import
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // Add import
import '../constants.dart';
import '../services/tracker_service.dart';
import '../widgets/status_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  // Traccar Credentials
  final _trackerService = TrackerService(
    username: 'pallorinaleoangelo@gmail.com',
    password: 'sentra1234',
  );

  bool _isLoading = false;
  Timer? _timer;
  Map<String, double>? _currentLocation;
  String? _error;

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
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _trackerService.dispose();
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

  Future<void> _fetchLocation() async {
    try {
      final position = await _trackerService.getDevicePosition(_deviceImei);

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

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Alert: Device is too far away!'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              // Reset counter if back in range
              _consecutiveFarReadings = 0;
            }
          }
        });

        if (isFirstLoad && position['lat'] != null && position['lng'] != null) {
          _mapController.move(LatLng(position['lat']!, position['lng']!), 15.0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
      await _trackerService.sendHexCommand(_deviceImei, hexCommand);

      if (!mounted) return;
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Area (Moved to top)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: displayCenter,
                          initialZoom: 15.0,
                        ),
                        children: [
                          ColorFiltered(
                            colorFilter: ColorFilter.matrix(<double>[
                              1.3, 0, 0, 0, 20, // R scale + offset
                              0, 1.3, 0, 0, 20, // G scale + offset
                              0, 0, 1.3, 0, 20, // B scale + offset
                              0, 0, 0, 1, 0, // Alpha
                            ]),
                            child: TileLayer(
                              urlTemplate:
                                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.sentra.app',
                            ),
                          ),
                          if (_currentLocation != null) ...[
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: displayCenter,
                                  radius: accuracy ?? 100,
                                  useRadiusInMeter: true,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
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
                                  width: 80,
                                  height: 80,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                      color: AppColors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.my_location,
                                      color: AppColors.primary,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      // Location Info Overlay
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              _error != null
                                  ? 'Error connecting'
                                  : (_currentLocation != null
                                        ? 'Location Found'
                                        : 'Searching...'),
                              style: const TextStyle(
                                color: Colors
                                    .white, // Changed to white for better contrast
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Cards
            Row(
              children: [
                StatusCard(
                  title: 'Module Battery',
                  value: _currentLocation != null
                      ? '${_currentLocation!['batteryLevel']}%'
                      : '...',
                  icon: Icons.battery_full,
                  iconColor: _currentLocation != null
                      ? (_currentLocation!['batteryLevel']! > 20
                            ? AppColors.primary
                            : Colors.red)
                      : Colors.grey,
                ),
                const SizedBox(width: 16),
                StatusCard(
                  title: 'LTE Signal',
                  value: _currentLocation != null
                      ? '${_currentLocation!['rssi']!.toInt()} dBm'
                      : '...',
                  icon: Icons.signal_cellular_alt,
                  iconColor: _currentLocation != null
                      ? (_currentLocation!['rssi']! > -100
                            ? Colors.blue
                            : Colors.orange)
                      : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Navigation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _currentLocation == null ? null : _openMaps,
                icon: const Icon(Icons.directions, color: Colors.white),
                label: const Text(
                  'NAVIGATE TO DEVICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buzzer Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _sendBuzzerCommand(true),
                    icon: const Icon(Icons.volume_up, color: Colors.white),
                    label: const Text(
                      'BUZZER ON',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _sendBuzzerCommand(false),
                    icon: const Icon(Icons.volume_off, color: Colors.white),
                    label: const Text(
                      'BUZZER OFF',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.grey[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Anti-Loss Toggle
            Container(
              height:
                  56, // Match standard button height (approx 56px with padding)
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: _antiLossEnabled ? AppColors.primary : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anti-Loss Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_distance != null && _antiLossEnabled)
                          Text(
                            'Distance: ${_distance!.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              height: 1.0,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _antiLossEnabled,
                    onChanged: (value) {
                      setState(() {
                        _antiLossEnabled = value;
                        if (!value) {
                          _distance = null; // Reset distance if disabled
                        }
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            if (_antiLossEnabled &&
                _currentLocation != null &&
                _lastUserPosition != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'DEBUG:\nPhone: ${_lastUserPosition!.latitude.toStringAsFixed(5)}, ${_lastUserPosition!.longitude.toStringAsFixed(5)}\nTracker: ${_currentLocation!['lat']?.toStringAsFixed(5)}, ${_currentLocation!['lng']?.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
