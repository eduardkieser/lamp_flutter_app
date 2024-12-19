class LampState {
  final double brightness;
  final double batteryVoltage;
  final String deviceName;

  LampState({
    required this.brightness,
    required this.batteryVoltage,
    required this.deviceName,
  });

  factory LampState.fromJson(Map<String, dynamic> json) {
    return LampState(
      brightness: json['brightness'].toDouble(),
      batteryVoltage: json['batteryVoltage'].toDouble(),
      deviceName: json['deviceName'] as String,
    );
  }
}
