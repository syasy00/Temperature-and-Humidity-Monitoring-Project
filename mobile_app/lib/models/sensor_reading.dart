// sensor_reading.dart
class SensorReading {
  final double temperature, humidity;
  final DateTime timestamp;

  SensorReading(this.temperature, this.humidity, this.timestamp);

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      double.tryParse(json['temperature'].toString()) ?? 0,
      double.tryParse(json['humidity'].toString()) ?? 0,
      DateTime.parse(json['timestamp']),
    );
  }
}
