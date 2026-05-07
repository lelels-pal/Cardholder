import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/history_entry.dart';
import '../services/database_service.dart';
import '../services/config_service.dart';
import '../services/tracker_service.dart';
import '../widgets/top_notification_modal.dart';
import 'history_map_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;
  bool _isLogging = false;

  static const String _deviceImei = '359339078106061';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _entries = await _dbService.getHistoryEntries(limit: 25);
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Manually fetches the current device position and logs it to history.
  Future<void> _logCurrentPosition() async {
    if (_isLogging) return;

    setState(() => _isLogging = true);

    try {
      final config = await ConfigService.getTraccarConfig();
      final username = config['username'] ?? '';
      final password = config['password'] ?? '';

      if (username.isEmpty || password.isEmpty) {
        if (mounted) {
          TopNotificationModal.show(
            context,
            message: 'Traccar credentials not configured. Go to Settings.',
            backgroundColor: Colors.red,
            icon: Icons.error_outline,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      final trackerService = TrackerService(username: username, password: password);
      final position = await trackerService.getDevicePosition(_deviceImei);

      if (position['lat'] != null && position['lng'] != null) {
        final entry = HistoryEntry(
          timestamp: DateTime.now(),
          latitude: position['lat']!,
          longitude: position['lng']!,
          accuracy: position['accuracy'],
          batteryLevel: position['batteryLevel'],
          rssi: position['rssi']?.toInt(),
        );

        await _dbService.insertHistoryEntry(entry);
        await _loadHistory(); // Refresh the list

        if (mounted) {
          TopNotificationModal.show(
            context,
            message: 'Position logged successfully!',
            backgroundColor: Colors.green,
            icon: Icons.check_circle,
            duration: const Duration(seconds: 2),
          );
        }
      }

      trackerService.dispose();
    } catch (e) {
      if (mounted) {
        TopNotificationModal.show(
          context,
          message: 'Failed to log position: $e',
          backgroundColor: Colors.red,
          icon: Icons.error,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLogging = false);
      }
    }
  }

  Future<void> _refreshHistory() async {
    await _loadHistory();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Device History',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_toggle_off,
                                  color: AppColors.textSecondary,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No history entries yet',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the button below to log current position',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshHistory,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HistoryMapScreen(entry: entry),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                color: AppColors.primary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatTimestamp(entry.timestamp),
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${entry.latitude.toStringAsFixed(5)}, ${entry.longitude.toStringAsFixed(5)}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          if (entry.accuracy != null ||
                                              entry.batteryLevel != null ||
                                              entry.rssi != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (entry.accuracy != null) ...[
                                                  Icon(
                                                    Icons.gps_fixed,
                                                    color: AppColors.textSecondary,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${entry.accuracy!.toStringAsFixed(0)}m',
                                                    style: const TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                ],
                                                if (entry.batteryLevel != null) ...[
                                                  Icon(
                                                    Icons.battery_full,
                                                    color: entry.batteryLevel! > 20
                                                        ? AppColors.primary
                                                        : Colors.red,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${entry.batteryLevel!.toStringAsFixed(1)}%',
                                                    style: const TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                ],
                                                if (entry.rssi != null) ...[
                                                  Icon(
                                                    Icons.signal_cellular_alt,
                                                    color: entry.rssi! > -100
                                                        ? Colors.blue
                                                        : Colors.orange,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${entry.rssi!} dBm',
                                                    style: const TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),

          // Log Now FAB
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _isLogging ? null : _logCurrentPosition,
              backgroundColor: _isLogging ? AppColors.textSecondary : AppColors.primary,
              icon: _isLogging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_location_alt, color: Colors.white),
              label: Text(
                _isLogging ? 'Logging...' : 'Log Now',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}