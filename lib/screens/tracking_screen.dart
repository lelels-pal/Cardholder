import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants.dart';
import '../services/tracker_service.dart';
import '../services/secure_storage_service.dart';

class TrackingScreen extends StatefulWidget {
  final String deviceImei;

  const TrackingScreen({super.key, required this.deviceImei});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();

  // Traccar Credentials loaded from secure storage
  TrackerService? _trackerService;

  bool _isLoading = false;
  Timer? _timer;
  Map<String, double>? _currentLocation;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  void _startLocationUpdates() {
    if (_trackerService == null) return;
    // Fetch immediately
    _fetchLocation();

    // Then every 5 seconds
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchLocation(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _trackerService?.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    if (_trackerService == null) return;
    try {
      final position = await _trackerService!.getDevicePosition(
        widget.deviceImei,
      );
      if (mounted) {
        setState(() {
          _currentLocation = position;
          _error = null;
        });

        // Optional: Move map to new location if it's the first update
        // _mapController.move(LatLng(position['lat']!, position['lng']!), 15);
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
      if (_trackerService == null) throw Exception('Tracker not initialized');
      await _trackerService!.sendHexCommand(widget.deviceImei, hexCommand);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Tracking')),
      body: Builder(
        builder: (context) {
          if (_error != null && _currentLocation == null) {
            return Center(child: Text('Error: $_error'));
          }

          if (_trackerService == null || _currentLocation == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final double lat = _currentLocation!['lat']!;
          final double lng = _currentLocation!['lng']!;
          final double accuracy = _currentLocation!['accuracy']!;

          final LatLng point = LatLng(lat, lng);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: point, initialZoom: 15.0),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.sentra.cardholder',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: point,
                        color: Colors.blue.withValues(alpha: 0.3),
                        borderStrokeWidth: 2,
                        borderColor: Colors.blue,
                        useRadiusInMeter: true,
                        radius: accuracy, // Accuracy in meters
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: CircularProgressIndicator(),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _sendBuzzerCommand(true),
                            icon: const Icon(Icons.volume_up),
                            label: const Text('BUZZER ON'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _sendBuzzerCommand(false),
                            icon: const Icon(Icons.volume_off),
                            label: const Text('BUZZER OFF'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              backgroundColor: AppColors.textSecondary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
