class ProvisioningConfig {
  final String deviceName;
  final String ssid;
  final String wifiPassword;
  final String userUuid;
  final String userPassword;
  final String backendUrl;
  final String? customField1;
  final String? customField2;

  ProvisioningConfig({
    required this.deviceName,
    required this.ssid,
    required this.wifiPassword,
    required this.userUuid,
    required this.userPassword,
    required this.backendUrl,
    this.customField1,
    this.customField2,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'ssid': ssid,
      'wifiPassword': wifiPassword,
      'userUuid': userUuid,
      'userPassword': userPassword,
      'backendUrl': backendUrl,
      if (customField1?.isNotEmpty == true) 'customField1': customField1,
      if (customField2?.isNotEmpty == true) 'customField2': customField2,
    };
  }
}