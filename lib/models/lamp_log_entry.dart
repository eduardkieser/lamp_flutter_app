class LampLogEntry {
  final DateTime timestamp;
  final double batteryVoltage;
  final double brightness;

  LampLogEntry({
    required this.timestamp,
    required this.batteryVoltage,
    required this.brightness,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'batteryVoltage': batteryVoltage,
        'brightness': brightness,
      };

  factory LampLogEntry.fromJson(Map<String, dynamic> json) => LampLogEntry(
        timestamp: DateTime.parse(json['timestamp']),
        batteryVoltage: json['batteryVoltage'],
        brightness: json['brightness'],
      );
}
