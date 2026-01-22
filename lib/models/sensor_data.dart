class SensorData {
  final String sensor;
  final num value;
  final String? unit;
  final DateTime timestamp;

  SensorData({
    required this.sensor,
    required this.value,
    this.unit,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      sensor: json['sensor_name'],
      value: json['value'],
      unit: json['unit'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
