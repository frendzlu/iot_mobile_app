class DeviceStatus {
  final String deviceName;
  final String? macAddress;
  final bool isWifiConnected;
  final bool isMqttConnected;
  final bool isRegistered;
  final String? wifiSsid;
  final String? mqttBrokerUrl;
  final String? errorMessage;
  final DateTime timestamp;

  const DeviceStatus({
    required this.deviceName,
    this.macAddress,
    required this.isWifiConnected,
    required this.isMqttConnected,
    required this.isRegistered,
    this.wifiSsid,
    this.mqttBrokerUrl,
    this.errorMessage,
    required this.timestamp,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      deviceName: json['deviceName'] ?? json['name'] ?? 'Unknown Device',
      macAddress: json['macAddress'],
      isWifiConnected: json['wifiConnected'] ?? false,
      isMqttConnected: json['mqttConnected'] ?? false,
      isRegistered: json['registered'] ?? false,
      wifiSsid: json['wifiSsid'],
      mqttBrokerUrl: json['mqttBrokerUrl'],
      errorMessage: json['error'],
      timestamp: json['timestamp'] != null 
        ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'macAddress': macAddress,
      'wifiConnected': isWifiConnected,
      'mqttConnected': isMqttConnected,
      'registered': isRegistered,
      'wifiSsid': wifiSsid,
      'mqttBrokerUrl': mqttBrokerUrl,
      'error': errorMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  DeviceStatus copyWith({
    String? deviceName,
    String? macAddress,
    bool? isWifiConnected,
    bool? isMqttConnected,
    bool? isRegistered,
    String? wifiSsid,
    String? mqttBrokerUrl,
    String? errorMessage,
    DateTime? timestamp,
  }) {
    return DeviceStatus(
      deviceName: deviceName ?? this.deviceName,
      macAddress: macAddress ?? this.macAddress,
      isWifiConnected: isWifiConnected ?? this.isWifiConnected,
      isMqttConnected: isMqttConnected ?? this.isMqttConnected,
      isRegistered: isRegistered ?? this.isRegistered,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      mqttBrokerUrl: mqttBrokerUrl ?? this.mqttBrokerUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Convenience getter for overall success status
  bool get isFullyProvisioned => isWifiConnected && isMqttConnected && isRegistered;

  /// Get human readable status description
  String get statusDescription {
    if (errorMessage != null) return 'Error: $errorMessage';
    
    final statuses = <String>[];
    if (isWifiConnected) statuses.add('WiFi Connected${wifiSsid != null ? ' to $wifiSsid' : ''}');
    if (isMqttConnected) statuses.add('MQTT Connected${mqttBrokerUrl != null ? ' to $mqttBrokerUrl' : ''}');
    if (isRegistered) statuses.add('Device Registered');
    
    if (statuses.isEmpty) return 'Provisioning in progress...';
    return statuses.join(' • ');
  }

  @override
  String toString() {
    return 'DeviceStatus{deviceName: $deviceName, wifi: $isWifiConnected, mqtt: $isMqttConnected, registered: $isRegistered}';
  }
}