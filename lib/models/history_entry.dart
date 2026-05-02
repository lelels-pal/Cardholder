class HistoryEntry {
  final int? id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? batteryLevel;
  final int? rssi;

  HistoryEntry({
    this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.batteryLevel,
    this.rssi,
  });

  // Convert to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'battery_level': batteryLevel,
      'rssi': rssi,
    };
  }

  // Create from Map (database row)
  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      latitude: map['latitude'],
      longitude: map['longitude'],
      accuracy: map['accuracy'],
      batteryLevel: map['battery_level'],
      rssi: map['rssi'],
    );
  }

  // Copy with method for updates
  HistoryEntry copyWith({
    int? id,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? batteryLevel,
    int? rssi,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
    );
  }
}