class ProvisioningConfig {
  final String deviceName;
  final String ssid;
  final String wifiPassword;
  final String userUuid;
  final String userPassword;
  final String backendUrl;

  ProvisioningConfig({
    required this.deviceName,
    required this.ssid,
    required this.wifiPassword,
    required this.userUuid,
    required this.userPassword,
    required this.backendUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'ssid': ssid,
      'wifiPassword': wifiPassword,
      'userUuid': userUuid,
      'userPassword': userPassword,
      'backendUrl': backendUrl,
    };
  }
}