class Device {
  final String name;

  Device({required this.name});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(name: json['name']);
  }
}
